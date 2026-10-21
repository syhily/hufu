# 发布流程

发布只依赖 GitHub：推送 `v*` tag 后，`.github/workflows/release.yml` 调用 `scripts/release.sh` 构建、签名（配置凭据时）、公证，并创建 **GitHub Release 草稿**。草稿由发布负责人检查后手动发布；没有额外的分发服务或更新清单。逐项检查见 [release-checklist.md](release-checklist.md)。

## 1. 发版

1. 同步版本号：`project.yml` 的 `MARKETING_VERSION` 和 `Packages/HufuKit/Sources/hufu/Hufu.swift` 的 CLI `version`。
   tag 去掉 `v` 和 `-` 后缀后必须与这两处一致（`v0.1.0-beta.1` 对应 `0.1.0`），不一致时工作流直接失败。
2. 在 `CHANGELOG.md` 与 `CHANGELOG.en.md` 中记好本次变更：条目只用新增 / 变更 / 修复 / 移除 / 安全 / 已知问题六类，
   中英文条数与分类一致。把 Unreleased 下的内容整理成本次版本段，并补上发布状态行。
   `python3 -m unittest discover -s scripts/tests -p 'test_changelog.py'` 检查格式、中英一致，以及最新版本与
   `MARKETING_VERSION` 一致；CI 也会跑。
3. 提交并等 CI 通过，然后打 tag 并推送：

   ```bash
   git tag -a v0.1.0 -m "Hufu 0.1.0"
   git push origin v0.1.0
   ```

4. 在 Actions 里等 Release 工作流跑完，到 Releases 页面检查草稿：附件、校验值、签名与公证状态，确认无误后点 Publish。

**试跑**：Actions › Release › Run workflow，填写 tag（如 `v0.1.0`，可以还不存在）。
试跑只把产物上传到这次运行的 artifact，不创建 Release。

**本地构建同样的产物**（不安装，只写 `build/` 和 `dist/`）：

```bash
bash scripts/release.sh v0.1.0   # → dist/release/Hufu-0.1.0.{pkg,zip}、SHA256SUMS.txt、RELEASE_NOTES.md
```

## 2. 产物

| 文件 | 内容 |
| --- | --- |
| `Hufu-<version>.pkg` | 安装包：`Hufu.app` 装到 `/Library/Input Methods`，`Hufu Settings.app` 装到 `/Applications` |
| `Hufu-<version>.zip` | `Hufu.app`（内含 CLI 和设置应用），手动放进 `~/Library/Input Methods/` |
| `SHA256SUMS.txt` | 上面两个文件的 SHA-256 |
| `RELEASE_NOTES.md` | `CHANGELOG.md` 的对应版本段 + 签名状态 + 校验值；写入 Release 正文，不作为附件 |

许可材料由构建脚本嵌入 `Hufu.app/Contents/Resources/LicenseMaterials/`（见 [发布清单](release-checklist.md)）。
安装包不包含任何原生 librime 插件，也不含 GPL 组件；发布说明与安装器许可页应只描述 MIT / BSD / Apache / OFL 与虎码官方免费数据。

## 3. 签名用的 secrets

在仓库 Settings › Secrets and variables › Actions 中添加。**7 个必须全部配置**才会签名并公证；
一个都没有则构建未签名预览版；只配了一部分时工作流报错，避免误发未签名版本。

| Secret | 内容 |
| --- | --- |
| `MACOS_DEVELOPER_ID_APP_P12_BASE64` | Developer ID Application 证书 + 私钥导出的 `.p12`，base64 编码 |
| `MACOS_DEVELOPER_ID_APP_P12_PASSWORD` | 上面 `.p12` 的导出密码 |
| `MACOS_DEVELOPER_ID_INSTALLER_P12_BASE64` | Developer ID Installer 证书 + 私钥导出的 `.p12`，base64 编码 |
| `MACOS_DEVELOPER_ID_INSTALLER_P12_PASSWORD` | 上面 `.p12` 的导出密码 |
| `APPLE_NOTARY_KEY_ID` | App Store Connect API Key 的 Key ID |
| `APPLE_NOTARY_ISSUER_ID` | App Store Connect API 的 Issuer ID |
| `APPLE_NOTARY_KEY_P8_BASE64` | 下载的 `AuthKey_<KeyID>.p8`，base64 编码 |

创建方法：

1. **证书**：用你的 Apple 开发者账号（Account Holder）创建两张 Developer ID 证书（Apple 说明：https://developer.apple.com/help/account/certificates/create-developer-id-certificates）。
   在「钥匙串访问」中选中证书（连同私钥），右键导出为 `.p12` 并设置密码。工作流只接受**有效**的身份，
   已过期或已吊销的证书会被拒绝（用吊销证书签名的程序会被 macOS 当作恶意软件移入废纸篓）。
2. **公证 API Key**：App Store Connect › 用户和访问 › 集成 › App Store Connect API › 团队密钥，新建一个 Developer 角色的密钥，
   记下 Key ID 和页面顶部的 Issuer ID；`.p8` 只能下载一次。
3. **写入 secrets**（在本机执行，不要把文件或 base64 内容贴进聊天或提交到仓库）：

   ```bash
   base64 -i DeveloperIDApplication.p12 | gh secret set MACOS_DEVELOPER_ID_APP_P12_BASE64 -R syhily/hufu
   gh secret set MACOS_DEVELOPER_ID_APP_P12_PASSWORD -R syhily/hufu          # 交互式输入
   base64 -i DeveloperIDInstaller.p12 | gh secret set MACOS_DEVELOPER_ID_INSTALLER_P12_BASE64 -R syhily/hufu
   gh secret set MACOS_DEVELOPER_ID_INSTALLER_P12_PASSWORD -R syhily/hufu
   gh secret set APPLE_NOTARY_KEY_ID -R syhily/hufu
   gh secret set APPLE_NOTARY_ISSUER_ID -R syhily/hufu
   base64 -i AuthKey_XXXXXXXXXX.p8 | gh secret set APPLE_NOTARY_KEY_P8_BASE64 -R syhily/hufu
   ```

工作流把证书导入一次性的临时钥匙串（随机密码），用 Hardened Runtime + 可信时间戳从内到外签名，
先公证并装订 `Hufu.app`，再打包、公证并装订 `.pkg`。无论成功失败，最后一步都会删除临时钥匙串和 `.p8`。

## 4. 未签名预览版

没有配置 secrets 时，产物只有 ad-hoc 签名、**未经 Apple 公证**，Release 标为 Pre-release，标题注明「预览版，未签名」，
说明里写清安装方法。macOS 首次打开会拦截，用户需要：

- `.pkg`：Finder 中右键 › 打开；新版 macOS 到「系统设置 › 隐私与安全性」点「仍要打开」。
  或只对这个文件执行 `xattr -d com.apple.quarantine Hufu-<version>.pkg`。
- `.zip`：解压，把 `Hufu.app` 放进 `~/Library/Input Methods/`，然后执行
  `xattr -dr com.apple.quarantine "$HOME/Library/Input Methods/Hufu.app"`。不要关闭系统全局 Gatekeeper。
- 安装后在「系统设置 › 键盘 › 输入法」添加「虎符输入法」；首次安装可能要注销重新登录一次。

已签名但带 `-beta` 等后缀的 tag 同样标为 Pre-release。

## 5. 校验下载

把下载的文件和 `SHA256SUMS.txt` 放在同一目录：

```bash
shasum -a 256 -c SHA256SUMS.txt          # 每行应为 OK
# 只下载了其中一个文件时：
shasum -a 256 -c SHA256SUMS.txt --ignore-missing
```

正式签名版还可以检查签名和公证：

```bash
pkgutil --check-signature Hufu-<version>.pkg     # 应显示 Developer ID Installer: <你的团队名> (<你的 Team ID>)
spctl --assess --type install --verbose=2 Hufu-<version>.pkg
xcrun stapler validate Hufu-<version>.pkg
```

应用本体：

```bash
codesign --verify --deep --strict --verbose=2 "/Applications/Hufu Settings.app"
codesign --verify --deep --strict --verbose=2 "/Library/Input Methods/Hufu.app"
spctl --assess --type execute --verbose=2 "/Library/Input Methods/Hufu.app"
xcrun stapler validate "/Library/Input Methods/Hufu.app"
```

## 公证还在排队时

新团队的首次公证可能排几个小时。`release.sh` 最多等 `HUFU_NOTARY_WAIT`（默认 20m）：超时不算失败，
产物照常签名、上传（Release 标题注明「公证处理中」），提交 ID 写入 `NOTARY_PENDING.txt`。Apple 通过后：

```bash
gh run download <run-id> -R syhily/hufu -D /tmp/hufu-release
bash scripts/finish-notarization.sh /tmp/hufu-release/Hufu-<版本>            # 装订票据、重算校验和
bash scripts/finish-notarization.sh /tmp/hufu-release/Hufu-<版本> --publish  # 替换 GitHub Release 上的文件
```

只有 Apple 判定 `Invalid` 才会让发布失败，并打印 `notarytool log`。
