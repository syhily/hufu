# 原生插件固定版本许可核对

> 2026-10-21 更新：Hufu 已把原生插件裁剪为只保留 `librime-lua`。`scripts/fetch-librime.sh` 在组装时排除 `librime-octagram` 与 `librime-predict`，`licenses/native-plugins/manifest.json` 只登记一个组件。发行包因此不再包含 GPL 组件，原审计中针对 GPL 组合程序与对应源码的发行义务不再适用。

## 审计经过

2026-10-01 的核对发现：`librime-octagram` 固定修订的 `LICENSE` 是 GPL-3.0，此前 `THIRD_PARTY_NOTICES.md` 把三个插件统一写为 BSD-3-Clause 并不准确。当时保留了完整的许可全文、固定链接、Git blob 与 Vendor 二进制哈希，用于判断组合程序范围。

2026-10-21 的裁剪决定直接消除了这个问题：Hufu 的虎码方案只依赖 librime-lua 提供的 Lua 过滤器与翻译器；octagram 的语法模型和 predict 的预测候选都不是内置方案所需。移除插件后，安装包中的第三方代码只剩 MIT、BSD、Apache 与 OFL 许可的组件，以及虎码官方免费发布的词库与方案数据。

## 插件清单

| 插件 | 固定源码修订 | 根目录 LICENSE | 现状 |
| --- | --- | --- | --- |
| librime-lua | `ec52e48ea18f11af37717a01c337f853215cf70b` | BSD-3-Clause | **随包分发**，位于 `Contents/Frameworks/rime-plugins/librime-lua.dylib` |
| librime-octagram | `dfcc15115788c828d9dd7b4bff68067d3ce2ffb8` | GPL-3.0 | **已于 2026-10-21 裁剪移除**（`fetch-librime.sh` 排除），GPL 组合程序问题随之消除 |
| librime-predict | `920bd41ebf6f9bf6855d14fbe80212e54e749791` | BSD-3-Clause | **已于 2026-10-21 裁剪移除**（`fetch-librime.sh` 排除） |

`licenses/native-plugins/` 现在只保留 `librime-lua.LICENSE.txt` 与单组件 manifest。manifest 记录：

- 引擎版本 `1.17.0`、commit 前缀 `33e7814`、压缩包 SHA-256；
- librime-lua 的固定源码 URL、许可 URL、许可 SHA-256、Git blob SHA-1；
- 重新签名前观察到的 Vendor 二进制 SHA-256（`9e5086f…`）；
- 包内路径 `Contents/Frameworks/rime-plugins/librime-lua.dylib`；
- 尚未通过的完整传递依赖审计与对应源码审计标记。

## 核对方法

1. 从官方仓库的固定修订获取许可全文，确认 HTTP 200，正文与缓存逐字一致，Git blob SHA-1 与官方固定树一致。
2. 对照 `Vendor/librime/version-info.txt`，确认短修订与固定完整修订的前缀相符；引擎压缩包版本与 SHA 来自 `Vendor/librime.lock`。
3. 用 `otool -L` 检查插件的 x86_64 与 arm64 切片，确认链接 `@rpath/librime.1.dylib`。
4. 检查 `scripts/embed-runtime.sh` 把 `rime-plugins` 复制到 `Contents/Frameworks/` 并重新签名；`RimeEngine.initialize` 调用 librime 的初始化接口。
5. 构建时由 `scripts/embed-license-materials.py` 核对：

   - manifest 中的许可 SHA-256；
   - Vendor 二进制的 SHA-256；
   - 刚复制进 App 的插件字节；
   - `rime-plugins/` 的目录成员必须与清单完全一致。

   清单外的插件、哈希不符或许可文件缺失都会让构建失败，且失败发生在写入 `Contents/Resources/LicenseMaterials/` 之前。

上述材料证明插件被打包、链接关系与输入哈希；短修订记录不能单独证明预编译产物的完整可复现来源，manifest 中的二进制 SHA 也只对应重新签名前的 Vendor 文件，不能用于校验最终安装包。

## 结论

- 发行包的原生插件只有 librime-lua（BSD-3-Clause），不再包含 GPL-3.0 的 librime-octagram，也不包含 librime-predict。
- 发行包整体包含 MIT / BSD / Apache / OFL 许可的组件与虎码官方免费发布的数据，**无 GPL 组件**。
- 因此不再需要为 octagram 准备 GPL 对应源码，也不再存在“Hufu + librime + octagram”的 GPL 组合程序问题。
- 许可嵌入仍保持“部分清单”定位：`completeLicensePackagingAuditPassed` 与 `completeCorrespondingSourceAuditPassed` 仍为 `false`。这只表示尚未完成全部传递依赖（例如 librime-lua 内嵌 Lua 的版本与声明）的逐项审计，不代表存在 GPL 义务。

## 后续工作

- 补齐 librime-lua 内嵌 Lua 的版本、版权与许可声明，以及其他传递依赖的 NOTICE。
- 解包最终安装包，核对 `Contents/Resources/LicenseMaterials/` 的 receipt、许可全文与原始 manifest，并单独记录签名后插件的哈希。
- 每次升级 librime 或改变插件集合时重新核对 manifest；`fetch-librime.sh` 与 `embed-license-materials.py` 都会拒绝与清单不一致的输入。
