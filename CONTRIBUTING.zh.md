# 为 Hufu 做贡献

[English](CONTRIBUTING.md) | **中文**

欢迎提交聚焦的问题报告、文档修正与代码。请遵守[行为准则](CODE_OF_CONDUCT.md)；安全漏洞按 [SECURITY.md](SECURITY.md) 反馈。可复现的问题提交到 [Issues](https://github.com/syhily/hufu/issues)，代码改动提交 [Pull Request](https://github.com/syhily/hufu/pulls)。

## 开发环境

使用 macOS 26+、已选择命令行工具的 Xcode 26+ 和 XcodeGen（`brew install xcodegen`）。Swift 包要求 Swift tools 6.2+，启用 Swift 6 strict concurrency。安装 SwiftLint 用于本地 lint 检查。脚本还会使用 Git、Bash、curl、Python 3 和 Ruby。记录实际使用的工具版本；CI 在 `macos-26` 上选择最新稳定版 Xcode。

`Packages/HufuKit` 包含 `RimeKit`、`HufuCore`、`HufuPanel`、`HufuAI` 和 `hufu` CLI。`project.yml` 定义两个 App target：`Hufu.app`（InputMethodKit/AppKit）和 `Hufu Settings.app`（SwiftUI）。模块边界见[架构文档](docs/architecture.md)与[架构决策记录](docs/decisions/)。

## 构建与安装

Fork 仓库，从当前默认分支创建聚焦本次改动的分支。clone 时带 `--recurse-submodules`（或在已有仓库中运行一次 `git submodule update --init`），以取得 `dicts/huma` 虎码 submodule。在仓库根目录运行：

```bash
bash scripts/fetch-librime.sh
mkdir -p Packages/HufuKit/.build
bash scripts/stage-huma.sh
swift build --package-path Packages/HufuKit
bash scripts/stage-plugins.sh
xcodegen generate
xcodebuild -project Hufu.xcodeproj -scheme Hufu -configuration Debug -derivedDataPath build/DerivedData build
```

脚本校验固定的 SHA-256，并组装 librime 与 `build/SharedSupport`。`stage-huma.sh` 直接采用 `dicts/huma` submodule 的虎码词表与方案（方案定制都在方案仓库完成），并预编译 librime 二进制产物；它也会调用插件暂存，因此首次运行前需创建 `.build`。每次构建新的 SwiftPM 配置后运行 `stage-plugins.sh`，让 `librime-lua` 位于该配置的 librime 副本旁。`Hufu` scheme 构建两个 App，其构建后脚本嵌入 Lua 插件与 SharedSupport。

为当前用户构建并安装：

```bash
bash scripts/install-dev.sh
```

安装脚本构建 Release App 与 CLI，安装到 `~/Library/Input Methods/Hufu.app` 并注册输入法。在系统设置 → 键盘 → 输入法中添加 Hufu；若没有出现，注销后重新登录。开发安装**默认使用 ad-hoc 签名**。不要使用已吊销证书：macOS 可能将其签名的 App 判为恶意软件并移入废纸篓。覆盖默认签名时，`HUFU_SIGN_IDENTITY` 只能设为有效的签名身份。

不要提交下载的二进制、生成的工程、构建产物或个人输入法数据。修改图标资源时，用 `swift scripts/gen-icons.swift` 重新生成 App 与菜单栏图标。

## 实现边界

- librime 用于输入法进程与 CLI，设置 App 不链接它。网络与 AI 工作置于按键路径之外。CI 通过 `hufu bench` 强制检查按键 p99 ≤ 5 ms；报告实际负载的测量结果，不把门槛当作所有环境下的保证。
- 启用 Swift strict concurrency。技术标识符和提交说明使用英文；有中英对等版本的文档同步更新。
- 导入时保护 `~/Library/Rime`，Hufu 数据仅写入独立目录；用临时样本测试 `__patch` 分层优先级和 dry-run 校验。
- AI 可选、由用户手动触发，默认使用 Apple 端侧模型。AI 只接收用户主动执行动作的那段文字（输入图层草稿、选区或刚上屏的字），编码串、候选列表、用户词频与统计一律不交给 AI；无遥测。应用配置修改前预览 diff。服务商 key 存在仅本人可读写的 `~/Library/Application Support/Hufu/credentials.json`（测试用 `HUFU_CREDENTIALS_FILE` 指向临时文件），不能进入仓库文件或测试日志。详见[隐私说明](docs/privacy.md)。
- 第三方方案、词表与 Lua 脚本与原创源码分开存放，保留来源、许可声明，并由脚本确定性地组装。
- 词库下载与应用源码分离，固定来源版本，执行 SHA-256 校验并保留上游许可声明。

## 许可证红线：禁止复制 GPL 源码

**禁止把 GPL 源码复制、翻译、移植或改写进 Hufu 的 MIT 源码树，包括 Squirrel 代码。** Hufu 不是 Squirrel 的 fork；这条要求也适用于基于此类代码生成的 AI 补丁。应独立实现，并使用兼容且注明来源的依赖。

`dicts/huma` 是指向 [hufu-scheme](https://github.com/syhily/hufu-scheme) 的 git submodule，虎码官方包的定制裁剪版（虎码秃版 2026.08.15，官方免费发布），随 App 的 `Contents/SharedSupport/` 分发；须保留上游版本、来源与许可声明。不要直接修改 submodule：修正应反馈给虎码官方，本地补充请放在 `huma_custom`（设置 › 自定义短语），产品侧的方案调整直接提交到方案仓库。不得把 GPL 实现代码引入 Hufu 的 MIT 源码。新增依赖或数据集时，在 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) 记录上游 URL、版本／commit、许可证及声明。来源或授权不明确时，先核实再引入，不能因仓库公开就视为 MIT。

原创代码贡献采用 MIT。不要粘贴未获授权的第三方词库内容；内置词表是官方发布物，不是社区词库投稿渠道。

## 测试与验证

完成上述构建准备后，按改动范围运行检查。Swift 包使用 Swift Testing，包含真实 librime 部署测试：

```bash
swift test --package-path Packages/HufuKit
python3 scripts/dictionary-metadata.py --shared-dir build/SharedSupport --check
swiftlint lint --config .swiftlint.yml
```

新行为与回归用例使用 Swift Testing。涉及相应模块时，覆盖部署／补丁优先级、非法 YAML、只读导入（源文件内容与时间戳不变）、下载校验失败、升级／卸载边界、AI 授权与数据隔离。测试使用临时目录和合成文本，不接触个人 RIME 文件或真实云端凭据。重试和批处理必须有次数上限。

修改输入路径时，构建 Release CLI、暂存对应插件，并使用临时用户目录运行基准：

```bash
swift build --package-path Packages/HufuKit -c release --product hufu
bash scripts/stage-plugins.sh
HUFU_BENCH_DIR="$(mktemp -d -t hufu-bench)"
"$(swift build --package-path Packages/HufuKit -c release --show-bin-path)/hufu" bench \
  --user-dir "$HUFU_BENCH_DIR" --shared-dir build/SharedSupport \
  --schema tigress --keys tuja --iterations 2000 --assert-p99-ms 5
```

附上硬件、macOS／工具链、词库／方案、负载、样本数、p99 延迟和常驻内存测量结果。p99 超过 5 ms 时，基准命令以失败状态退出。

修改 UI 时，完成上述 Debug App 构建后，在已登录的图形会话中授予屏幕录制权限并运行：

```bash
bash scripts/ui-shots.sh
```

亮色与暗色截图保存到 `.ui-acceptance/<日期>/`。还需检查正常与窄窗口宽度、键盘操作、截断和候选窗定位。使用安装脚本的 Release 产物时，运行 `APP="$PWD/build/DerivedData/Build/Products/Release/Hufu Settings.app" bash scripts/ui-shots.sh`。

[CI](.github/workflows/ci.yml) 下载依赖、暂存插件、运行包测试与 Release 基准、校验词库，并构建、归档未签名 App。SwiftLint 与截图属于本地检查。[docs/privacy.md](docs/privacy.md) 中的隐私验收要求以下命令无匹配结果（这是独立的本地检查，不是当前工作流中的步骤）：

```bash
! grep -rlE 'composing|preedit|userdb' Packages/HufuKit/Sources/HufuAI
```

仅改文档时，保持中英文语义一致并检查本地链接。用以下命令解析仓库 YAML：

```bash
ruby -ryaml -e '(Dir[".github/ISSUE_TEMPLATE/*.yml"] + [".swiftlint.yml", "project.yml", ".github/workflows/ci.yml"]).each { |f| YAML.parse_file(f) }'
```

## 提交与 Pull Request

采用 [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)：`type(scope): summary`，scope 可省略。例如：`docs: clarify setup status`、`fix(rime): preserve imported overrides`、`feat(settings): preview candidate colors`。不兼容变更使用 `!` 和 `BREAKING CHANGE:` 尾注。

1. 先搜索已有 issue；较大的行为或依赖调整先讨论再实现。
2. 每个分支／PR 只处理一个问题，小步提交，不顺手重构无关代码。
3. 运行相关检查，审查 diff 中的凭据、个人数据、生成物与许可证来源，再提交。由 Codex 代提交时，末尾加 `Co-Authored-By: Codex <noreply@openai.com>`。
4. 填写 PR 模板：问题、改后行为、关联 issue、准确的验证结果与限制。涉及双语 README／贡献指南时同步更新；已实现改动写入 changelog 的 `Unreleased`，待办用 GitHub Issues 跟踪。
5. 请求审查并处理反馈。没有运行记录就不能称 CI 已通过，未经授权不得替维护者合并或发布。

排障与诊断导出见[排障指南](docs/troubleshooting.md)。
