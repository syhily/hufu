# 插件许可嵌入验收（2026-10-01，2026-10-21 按单插件现状重述）

> 2026-10-21：Hufu 的原生插件已裁剪为只有 `librime-lua`。`librime-octagram`（GPL-3.0）与 `librime-predict` 由 `scripts/fetch-librime.sh` 排除，`licenses/native-plugins/manifest.json` 只登记一个组件。本文保留原验收方法与历史证据，并按“仅 librime-lua”重述 B01 系列结论。GPL 对应源码义务不再适用。

## B01 系列结论

| 项 | 范围 | 结论 |
| --- | --- | --- |
| B01a 插件清单 | 包内只有 `librime-lua.dylib` | **通过**：manifest 单组件，`embed-license-materials.py` 要求包内 `rime-plugins/` 成员与清单完全一致，清单外插件直接拒绝 |
| B01b 许可材料嵌入 | librime-lua 许可全文、来源清单、Hufu MIT、第三方声明、审计与发布说明 | **通过（脚本层）**：当前 `scripts/tests/test_license_materials.py` 的 5 项测试全部通过，覆盖正确嵌入、许可损坏、Vendor 替换、包内插件被修改或新增、清单路径穿越 |
| B01b2 实际构建产物 | 构建出的 `Hufu.app` 是否真的带有这些材料 | **待用单插件构建复核**：2026-10-01 的三插件构建曾通过；裁剪后尚未重新跑完整 App 构建与解包核对 |
| B01c 完整依赖审计 | 全部传递依赖、内嵌 Lua、对应对应源码 | **未通过**，与裁剪无关；`completeLicensePackagingAuditPassed` 与 `completeCorrespondingSourceAuditPassed` 仍为 `false` |

B01c 未通过不再意味着 GPL 义务。它表示 librime-lua 内嵌 Lua 的版本与声明等传递依赖尚未逐项审计；发行包本身不含 GPL 组件。

## 实际行为

`scripts/embed-runtime.sh` 复制插件后，在签名前运行 `scripts/embed-license-materials.py`。脚本核对许可 SHA-256、Vendor 二进制 SHA-256、刚复制的插件字节及插件目录成员。不符合固定清单时返回非零，停止该构建；它不会删除已有资源或重写源清单。

材料位于 `Contents/Resources/LicenseMaterials/`：

- Hufu MIT 许可；
- 第三方声明；
- librime-lua 完整许可；
- 原始单组件 manifest；
- 原生插件许可审计与发布检查清单；
- 范围说明 `README.txt`；
- 校验 receipt。

共 7 份内容文件，另有 `packaging-receipt.json`。原始 manifest 保留未通过项；receipt 同样把完整许可审计与完整对应源码审计标为 false。Vendor 输入哈希在签名前核对，不能用来校验重新签名后的插件；最终插件哈希需另行记录。

## 验证证据

| 检查 | 实际结果 | 证据（gitignored） |
| --- | --- | --- |
| 许可嵌入测试 | `test_license_materials` 5 项通过：正确嵌入、损坏许可、替换 Vendor、修改或增加包内插件、清单路径穿越；拒绝发生在写入资源前 | `python3 -m unittest discover -s scripts/tests -v` |
| Manifest 单组件 | `licenses/native-plugins/manifest.json` 只含 `librime-lua`；octagram/predict 已删除 | 仓库文件 |
| 历史三插件构建 | 2026-10-01：Xcode Release 构建 `** BUILD SUCCEEDED **`；ZIP 解包逐项校验 9 个内容文件；lua、octagram、predict 均含 x86_64 与 arm64；ad-hoc 签名 `codesign --verify --deep --strict` 退出 0 | `build/release-audit/license-packaging-verification.json`、`license-packaging-isolated-build.log` |
| 历史拒绝测试 | 2026-10-01：5 项测试覆盖错误输入被拒 | `build/release-audit/license-packaging-tests.log` |

历史构建的测试 ZIP 为 `build/license-packaging-check/Hufu-license-check.zip`，SHA-256 `172e4f2f6c2535c91b96351c151c733903eacec60dcdcd7e2c4ffb2e7182d626`。该 ZIP 含已裁剪的 octagram/predict，只用于说明当时的脚本行为，**不是当前发行包**。

## 尚未证明的范围

- 裁剪后没有重新组装完整套件（输入法、设置 App、CLI 与 `.pkg`），也没有新的解包、安装、输入、Developer ID 签名或公证记录。
- 历史 ZIP 只用于 Xcode 输入法 App 的资源验收，不等于正式发行验收。
- librime-lua 内嵌 Lua 的版本与完整声明、其他传递依赖许可仍待审计。
- 当前构建会在签名前拒绝清单外的插件，这条约束由脚本测试覆盖，但不能代替对新产物的解包核对。

测试命令：

```sh
python3 -m unittest discover -s scripts/tests -v
```
