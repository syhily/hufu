# Hufu 发布检查清单

每次发布逐项勾选，记录提交 SHA、工具链、测试日志和未解决问题；未验证项不得写成已通过。流程说明见 [releasing.md](releasing.md)。

## 版本与构建

- [ ] 同步版本号：`project.yml` 的 `MARKETING_VERSION` 与 `Packages/HufuKit/Sources/hufu/Hufu.swift` 的 CLI `version`。tag 去掉 `v` 和 `-` 后缀后必须与这两处一致；`scripts/release.sh` 会再次校验，不一致直接失败。
- [ ] 更新 `CHANGELOG.md` 与 `CHANGELOG.en.md`：把已验证的改动从 `Unreleased` 移到新版本，写明日期；中英文的版本、日期、类型和条目数必须一致。
- [ ] 记录 `xcodebuild -version`、`swift --version`、macOS 版本与 CPU 架构。CI 在 `macos-26` 上选择最新稳定 Xcode；发布前核对实际版本。
- [ ] 发布提交的 CI 全绿：CHANGELOG 格式检查、SwiftPM 构建与测试、Release CLI、p99 门禁、词库元数据检查、Xcode Release 构建与 artifact 上传。
- [ ] 执行 `python3 -m unittest discover -s scripts/tests -v`，确认 CHANGELOG、词库元数据与许可材料测试全部通过。
- [ ] 核对 `Vendor/librime.lock`、`dicts/huma` submodule 的来源与固定 commit（应为 [hufu-scheme](https://github.com/syhily/hufu-scheme) 的预期修订）；确认 `scripts/fetch-librime.sh` 用 ghostflyby 静态包组装 `CRime.xcframework`，官方预编译包只提供 `rime_deployer`、OpenCC 数据与暂存用动态库。
- [ ] **确认产物自包含**：`Hufu.app/Contents/Frameworks/` 不存在（或为空），不存在 `rime-plugins/`；`otool -L` 检查 `Hufu.app/Contents/MacOS/Hufu` 与 `Contents/Helpers/hufu` 均不引用 `librime.1.dylib`。
- [ ] 解包最终安装包，核对 `Contents/Resources/LicenseMaterials/` 的 `packaging-receipt.json`、Hufu MIT 许可与第三方声明；receipt 应标明 `nativePluginsBundled: false`，第三方声明应注明 librime 的静态来源与 sha256。
- [ ] 核对安装器许可页与发布说明中的许可段落：`scripts/pkg/LICENSE-header.txt`、`scripts/package.sh` 的许可拼接、`scripts/release.sh` 生成的 `RELEASE_NOTES.md` 都应只描述 MIT / BSD / Apache / OFL 与虎码官方免费数据，不应再引用已删除的 octagram 许可文件或声称整体按 GPL 分发。

## 本地安装与输入实测

- [ ] 备份现有 Hufu 用户配置；在 macOS 26+ 测试机执行下列步骤。`install-dev.sh` 会替换当前用户的 Hufu 并终止旧进程，先保存正在输入的内容。

```bash
bash scripts/fetch-librime.sh
bash scripts/stage-huma.sh
swift build --package-path Packages/HufuKit
swift test --package-path Packages/HufuKit
bash scripts/install-dev.sh
```

- [ ] 在系统设置启用 Hufu，必要时注销并重新登录；运行 `"$HOME/Library/Input Methods/Hufu.app/Contents/Helpers/hufu" doctor`，检查方案与路径（不应列出任何原生插件）。
- [ ] 在 **TextEdit、Safari、VS Code、微信** 中实测虎码连续输入、候选翻页与选择、空格 / 回车上屏、退格、标点、中英切换、焦点切换与应用重启，记录应用版本。
- [ ] 验证设置 App 各页面能打开，修改配置后几秒内自动生效，界面上不出现任何「部署」按钮或状态；确认已有用户配置与词频未被意外覆盖。
- [ ] 验证自定义短语：在设置中添加一条带虎码编码的短语，几秒后能直接打出（不需手动应用任何东西）。
- [ ] 验证导入：用临时 RIME 目录只读导入，确认源目录内容与时间戳不变；拼音码表应提示需改为虎码编码。
- [ ] 对最终下载的 `.pkg` / `.zip` 另做安装与输入冒烟测试，并确认 `Hufu Settings.app` 安装到 `/Applications`。

## 性能与内存

- [ ] 执行与 CI 相同的 Release 基准，保留 p50 / p90 / p99 / max、机器型号、系统版本与词库版本；p99 必须 ≤ 5 ms。使用临时用户目录，避免改写日常词频。

```bash
swift build --package-path Packages/HufuKit -c release --product hufu
HUFU_BENCH_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hufu-bench.XXXXXX")"
"$(swift build --package-path Packages/HufuKit -c release --show-bin-path)/hufu" bench \
  --user-dir "$HUFU_BENCH_DIR" --shared-dir build/SharedSupport \
  --schema tigress --keys tuja --iterations 2000 --assert-p99-ms 5
```

- [ ] 测量输入法进程的常驻内存：`ps -o pid=,rss=,etime=,command= -p "$(pgrep -x Hufu)"`，RSS 单位为 KiB。记录空闲、连续输入 10 分钟和改动设置触发重建后的数值；超标须定位或在发布说明中如实披露。
- [ ] 可用 `/usr/bin/time -l` 包裹 bench 命令记录 CLI 峰值内存；该结果不能代替输入法进程的常驻内存。

## 签名与公证

- [ ] 发布使用你自己的 Apple 开发者团队；按 [发布流程](releasing.md) 核对证书、账号角色与公证凭据。Apple Development 构建不能用于正式分发。
- [ ] 正式签名使用有效、未吊销的 **Developer ID Application** 与 **Developer ID Installer** 证书，启用 Hardened Runtime 与可信时间戳。**切勿使用已吊销证书**：macOS 会将其签名的应用判为恶意软件并移入废纸篓。
- [ ] `install-dev.sh` 默认 ad-hoc 签名且不要求时间戳，不能替代正式发布签名。
- [ ] 配置 7 个发布 secret 后，Release 工作流会导入一次性钥匙串，签名并公证 `Hufu.app` 与 `.pkg`，最后删除临时钥匙串与 `.p8`。缺少任一项时工作流报错；完全没有 secret 时才构建未签名预览版。
- [ ] 公证尚未完成时，`release.sh` 会把提交 ID 写入 `NOTARY_PENDING.txt` 并继续上传；Apple 接受后用 `scripts/finish-notarization.sh` 装订票据、重算校验和并替换 Release 文件。只有 `Invalid` 会让发布失败。

## GitHub Release

- [ ] 确认版本提交与 CI 成功运行的 SHA 一致，创建并推送 `vX.Y.Z` tag。推送后 `release.yml` 构建、签名（有 secrets 时）、公证，并创建 **草稿 Release**。
- [ ] 在 Actions 中确认 Release 工作流完成，产物为：

  - `Hufu-<version>.pkg`
  - `Hufu-<version>.zip`
  - `SHA256SUMS.txt`
  - `RELEASE_NOTES.md`（写入 Release 正文，不作为附件）
  - `NOTARY_PENDING.txt`、`SIGNING_STATUS`（内部状态）

- [ ] 到 Releases 页面检查草稿：附件、校验值、签名 / 公证状态、最低系统版本、支持的架构、包内组件、安装升级步骤、已知问题。
- [ ] 预览草稿，确认标题与预发布标记正确（未签名或公证处理中应为 Pre-release）；由发布负责人手动 Publish。
- [ ] 从 Release 页面重新下载产物，验证 SHA-256，并在干净测试环境复测安装、输入与卸载；保存 Release 链接与实测证据。

## 安装包（.pkg）

```bash
bash scripts/package.sh                       # → dist/Hufu-<version>.pkg（未签名）
HUFU_SIGN_IDENTITY=<Developer ID Application 哈希> \
HUFU_INSTALLER_IDENTITY="Developer ID Installer: …" bash scripts/package.sh
```

- 安装到 `/Library/Input Methods/Hufu.app`；`Hufu Settings.app` 同时装到 `/Applications`；`postinstall` 以当前登录用户身份执行 `Hufu --install`。
- macOS 对首次安装的第三方输入法可能拒绝立即选中（`TISSelectInputSource` 返回 -50），需要用户手动添加或注销重新登录；安装器结束页已写明。
- 首次启动时若 `~/Library/Rime` 存在且 Hufu 用户目录为空，会自动只读导入鼠须管配置。
- 正式发布在 CI 的干净环境打包，避免本机扩展属性产生 `._*` 条目。
