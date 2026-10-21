# ADR-0006：librime 源码入树、项目内自编译

- 状态：已接受 · 2026-10-22
- 取代：[ADR-0001](0001-librime-prebuilt-engine.md)

## 背景

ADR-0001 采用官方预编译包。随后应用与 CLI 改为静态链接时，又引入了
ghostflyby/librime-xcframework 的静态产物。结果是同一版本存在两个不同构建：

- `rime_deployer` 等暂存工具运行官方动态 `librime.1.dylib`；
- 应用与 CLI 链接 ghostflyby 的静态 `librime.a`。

两者来源、编译选项和依赖版本不完全一致，难以审计，也无法按产品需要关闭日志、
插件或测试代码。官方静态包还把 lua/octagram/predict 等插件对象合并进 archive，
即使最终没有链接，构建输入仍不够干净。

## 决策

- 把 librime 与其依赖的源码作为 git submodule 固定在 `Vendor/src/`：
  - librime `1.17.0`（`33e7814`）
  - leveldb `1.23`（`99b3c03`）
  - marisa-trie `v0.3.1`（`3e87d53`）
  - OpenCC `ver.1.1.9`（`556ed22`）
  - yaml-cpp `2f86d13`（librime 1.17.0 固定的 commit，0.8.0 之后）
- Boost 仍被 librime 直接使用（`signals2`、`unordered`、`regex`、`crc`、`dll`、
  `interprocess`、`range`、`scope_exit`、`uuid`），不能删除。Boost 1.89.0 的源码
  压缩包按 sha256 固定，由构建脚本下载到 `build/rime/cache/` 后本地编译；没有作为
  submodule 引入，避免 CI 递归拉取上百个 Boost 子模块。
- `scripts/build-librime.sh` 统一构建一个 universal（arm64 + x86_64）、macOS 15.0、
  Release、PIC、静态的 librime：
  - `BUILD_SHARED_LIBS=OFF`、`BUILD_STATIC=ON`
  - `ENABLE_LOGGING=OFF`，因此不引入 glog/gflags
  - 关闭测试、示例、数据和全部依赖的测试/工具/文档
  - 补丁只做两件事：让 `add_subdirectory(tools)` 在静态构建下也执行；macOS 下
    `find_package(Boost … COMPONENTS regex)`，让静态工具能链接 Boost.Regex。
- `libtool -static` 合并 librime、yaml-cpp、leveldb、marisa-trie、OpenCC 与
  Boost.Regex 为单一 `build/rime/lib/librime.a`，再生成与原先完全一致的
  `CRime.xcframework`（module `CRime`、同样的伞头与 `module.modulemap`）。
- 所有生成物移到 `build/rime/`：`bin/` 放静态 `rime_deployer` 等工具，
  `share/opencc/` 放源码构建的 OpenCC 数据。`Vendor/librime/` 不再生成。

## 影响

- 单一引擎实例：暂存工具、应用和 CLI 使用同一份源码、同一组编译选项。
- 冷构建需要编译 librime 及依赖，并首次下载 Boost 源码；CI 用 submodule 清单 +
  构建脚本哈希缓存 `build/rime` 与 `CRime.xcframework`。
- 关闭 glog 后 librime 不再写日志文件；排障依赖 Hufu 自己的诊断输出。
- 依赖许可全文按 `licenses/` 落盘，并随 `THIRD_PARTY_NOTICES.md` 一起分发。
- 升级 librime 或任一依赖需要更新 submodule、`Vendor/librime.lock` 和
  `THIRD_PARTY_NOTICES.md`，然后重新冷构建。
