# ADR-0001：以 librime 预编译包为引擎

- 状态：已接受 · 2026-09-29

## 背景

Hufu 的目标用户已经拥有 RIME 格式的方案、词库、lua 扩展和语法模型。性能是第一优先级。

## 决策

- 不自研引擎，使用 librime。官方 **1.17.0（commit 33e7814）macOS universal 预编译包**
  提供 OpenCC 数据与 `rime_deployer` 等暂存工具；应用与 CLI 的引擎代码来自
  [ghostflyby/librime-xcframework](https://github.com/ghostflyby/librime-xcframework) 的静态包
  `1.17.0-pack.10.0.0`（同一上游）。`Vendor/librime.lock` 记录全部 sha256，
  `scripts/fetch-librime.sh` 下载校验后组装 `CRime.xcframework`；Hufu 不组装或分发任何可动态加载的插件目录。
- Swift 侧通过 `rime_get_api_stdbool()` 调用，封装在 RimeKit，所有调用限定在主 actor。
- librime 历史上会从 `librime.1.dylib` 同级的 `rime-plugins/` 目录加载插件；Hufu 现已不捆绑任何原生插件 dylib。

## 备选

| 方案 | 否决原因 |
|---|---|
| 自研引擎 | 多年工作量，且放弃整个 RIME 生态 |
| Homebrew librime | 链接到 /opt/homebrew，无法随 App 分发 |
| 源码 submodule + CMake + Boost | 首次构建 20 分钟以上，贡献门槛高；列入 Roadmap（R01）作为可复现构建 |

## 影响

- 升级引擎 = 同时更新官方包的版本/commit 与静态包的 tag/sha256。
- 静态链接后应用和 CLI 自包含，没有需要随包重签的 librime dylib；`Vendor/lib/librime.1.dylib`
  只供暂存工具运行，不进入产物。

## 现状注记（2026-10-22）

应用与 CLI 已改为**静态链接** `ghostflyby/librime-xcframework` 的 `1.17.0-pack.10.0.0`
（`librime.a`，sha256 固定在 `Vendor/librime.lock`）。`scripts/fetch-librime.sh` 仍保留官方
1.17.0 预编译包的 `rime_deployer`、OpenCC 数据与动态 `librime.1.dylib`，仅用于
`stage-huma.sh` 在构建期预编译词库。`Hufu.app` 不再包含 `Contents/Frameworks/`，也不再复制
`rime-plugins/`；发行包不包含任何可动态加载的原生插件，也不含 GPL 组件。
