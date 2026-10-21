<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/brand/hufu/base-v1/lockup-white.png">
    <img src="assets/brand/hufu/base-v1/lockup-color.png" width="300" alt="Hufu · 虎符输入法">
  </picture>
</p>

<p align="center"><b>虎符输入法 Hufu</b></p>

<p align="center">基于 librime 的 macOS 虎符输入法 · 只内置虎码 · 本地优先 · 可选 AI</p>

<p align="center">
  <a href="https://github.com/syhily/hufu/releases">下载</a> ·
  <a href="docs/README.md">文档</a> ·
  <a href="docs/privacy.md">隐私说明</a> ·
  <a href="README.en.md">English</a>
</p>

<p align="center">
  <a href="https://github.com/syhily/hufu/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/syhily/hufu/ci.yml?branch=main&style=flat-square&label=CI" alt="CI"></a>
  <a href="https://github.com/syhily/hufu/releases"><img src="https://img.shields.io/github/v/release/syhily/hufu?include_prereleases&style=flat-square&label=release" alt="Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-2f855a?style=flat-square" alt="MIT"></a>
  <img src="https://img.shields.io/badge/macOS-15%2B-111111?style=flat-square&logo=apple" alt="macOS 15+">
  <img src="https://img.shields.io/badge/Swift-6-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift 6">
  <img src="https://img.shields.io/badge/librime-1.17-B64032?style=flat-square" alt="librime 1.17">
</p>

Hufu 是虎码的 macOS 输入法前端。它把 [librime](https://github.com/rime/librime) 装进原生输入法进程，内置虎码官方码表，用一个设置 App 管理输入习惯；不提供方案切换，也不内置其他拼音或形码方案。项目派生自 AIME。

**产品定位：Hufu 不提供 Rime 常见的输入方案定制功能**——不支持增删或自制方案，也不提供方案补丁编辑界面；但开放自定义编码词库（`huma_custom`，在设置页维护）。

> **早期版本（0.1.x）。** 功能仍在收敛。正式发布使用 Developer ID 签名并送 Apple 公证；未配置签名凭据的构建是 ad-hoc 签名的预览版。每个 Release 的实际状态以该版本说明为准。

## 特性

- **只做虎码**：方案列表只有虎码（schema id `tigress`）。官方秃版 2026.08.15 通过 `dicts/huma` submodule 引入（[hufu-scheme](https://github.com/syhily/hufu-scheme)），词表在方案仓库裁剪为单字与四字及以下词组。
- **内置码表**：单字 117,662 条、词组 125,655 条、简码词 3,134 条，共 246,451 条原始记录（按来源文件递归统计，未去重）。
- **保留官方方案能力**：`` ` `` 拼音反查（PY_c）、`'` 临时英文（easy_english）、拆分提示（chaifen）、拼音注解、emoji 注解。
- **简繁四模式**：繁简混打（默认，按《通用规范汉字表》一级→二级→三级排序，繁体字形殿后）、打简出繁（候选同样限定在 8105 字集内）、只打繁体、只打简体；繁体标准可选虎码 `st_tu`、台湾正体、香港繁体或通用繁体。
- **原生候选窗**：AppKit + Core Text 自绘，候选可横排一行或竖排列表，支持亮暗配色、字体字号与圆角间距调整；主题可用 `hufu-ime://` 链接导入。
- **可视化设置**：概览、AI 助手、输入统计、输入习惯、中英切换、快捷键、外观、应用、词库、自定义短语、常用语、同步与备份、高级、关于。
- **AI 助手（可选）**：Apple 端侧模型（Foundation Models，macOS 26）或 OpenAI 兼容接口；⌃⌥P 触发翻译、润色与自定义动作；支持自然语言改配置、从文章中提取词汇（编码需手工补虎码）。
- **自定义短语**：在设置里维护 `huma_custom` 表，手工填写虎码编码，合并进虎码主词典，改完几秒后自动生效。
- **常用语与统计**：分类保存手机号、地址等常用内容；输入统计只存本机，可关闭、可清空。
- **同步与备份**：通过 RIME 同步目录在多台 Mac 间合并词频；Hufu 不运营同步服务器。也可导出 / 恢复本地备份文件。
- **从其他输入法导入**：可只读导入鼠须管、小狼毫、fcitx 的 RIME 词库、自定义短语、配色与词频快照；方案与方案补丁不导入，拼音码表需要自行改成虎码编码。
- **许可干净**：安装包不包含任何可动态加载的原生插件，也不含 GPL 组件。

## 安装

系统要求：**macOS 15 或更高版本**（Apple 端侧模型等 AI 功能需 macOS 26）。输入法 App 与随包的 `hufu` 命令行工具均为 universal 构建，同时支持 Apple 芯片与 Intel。

1. 在 [Releases](https://github.com/syhily/hufu/releases) 下载最新的 `Hufu-<版本>.pkg`，并与同页的 `SHA256SUMS.txt` 核对：

   ```bash
   shasum -a 256 -c SHA256SUMS.txt --ignore-missing
   ```

2. 阅读该版本的签名与公证状态，再按 Release 说明安装。配置好 Developer ID 凭据前，发布产物为 ad-hoc 签名的预览版（首次打开需在「系统设置 › 隐私与安全性」放行）。
3. 打开 **系统设置 › 键盘 › 输入法 › 编辑…**，点 **+**，在「简体中文」中添加 **虎符输入法**。首次安装后若列表里没有，注销并重新登录一次。

目前没有 Homebrew cask，请从 Releases 安装。

## 从源码构建

需要 macOS 15+（开发用）、Xcode 26+、[XcodeGen](https://github.com/yonaskolb/XcodeGen)（`brew install xcodegen`）和 Python 3。

```bash
git clone --recurse-submodules https://github.com/syhily/hufu.git
cd hufu

bash scripts/fetch-librime.sh    # 下载并校验 librime 1.17.0，组装静态 CRime.xcframework
bash scripts/stage-huma.sh       # 过滤虎码词表，组装 build/SharedSupport
bash scripts/build-app.sh        # → build/Release/Hufu.app
bash scripts/install-dev.sh      # 安装到 ~/Library/Input Methods 并注册
```

已经 clone 过仓库的话，先初始化方案数据：`git submodule update --init`。`dicts/huma` 是指向 [hufu-scheme](https://github.com/syhily/hufu-scheme) 的 submodule（虎码官方秃版 2026.08.15 的定制裁剪版），固定到某个 commit；方案内容（词表裁剪、schema 调整）全部在方案仓库维护，本仓库不直接修改 submodule 内容。

`stage-huma.sh` 默认保留四字及以下词组，可用环境变量调整：

```bash
HUFU_MAX_PHRASE_LEN=4 bash scripts/stage-huma.sh
```

也可以生成 Xcode 工程后手动构建：

```bash
bash scripts/fetch-librime.sh && bash scripts/stage-huma.sh
xcodegen generate
open Hufu.xcodeproj
```

工程由 `project.yml` 生成，`.xcodeproj` 不入库。开发安装默认使用 ad-hoc 签名；只有设置 `HUFU_SIGN_IDENTITY` 时才会使用指定的 Developer ID 身份。

## 使用要点

| 按键 | 作用 |
| --- | --- |
| `;` | 选第 2 个候选 |
| `'` | 选第 3 个候选（有候选时） |
| `-` / `=` | 上一页 / 下一页 |
| Tab | 清空当前编码 |
| `` ` `` | 进入拼音反查（`PY_c`） |
| `'` 开头 | 临时英文（`easy_english`），回车或空格上屏 |
| ⌃O | 临时切换简繁（混打 ↔ 打简出繁） |
| ⌃H | 切换全字集 / 常用字 |
| ⌃P | 拼音注解开关 |
| ⌃I | emoji 注解开关 |
| ⌃J | 拆分提示开关 |
| ⌃⇧3 / ⌃⇧4 | 中英标点 / 简繁（同上） |
| F4 或 Control + \` | 方案选单（切换开关） |

以上键位来自虎码官方方案与内置 `default.yaml`；可在 **设置 › 快捷键** 与 **设置 › 高级** 中调整。

设置 App 的页面：

- **概览**：输入法状态、配置状态、导入入口、诊断导出。
- **AI 助手**：端侧 / 自备接口、AI 动作、输入图层、配置助手、词汇提取。
- **输入统计**：每日字数、时段与应用分布、高频词置顶。
- **输入习惯**：候选数量、简繁四模式与繁体标准、虎码开关、标点、便利功能（时间日期 / 计算器 / 大写数字）等。
- **中英切换**：Caps Lock 与 Shift 的行为、按应用状态。
- **快捷键**：快捷菜单长按键、方案选单、翻页与选词键。
- **外观**：主题与配色、字体字号、候选排列、圆角与间距；支持 `hufu-ime://` 主题链接。
- **应用**：按应用设置默认中英文。
- **词库**：内置虎码词库信息卡（版本、来源、单字 / 词组 / 记录数）。
- **自定义短语**：维护 `huma_custom`，手工填写虎码编码。
- **常用语**：分类管理常用文本。
- **同步与备份**：词频同步目录、导出 / 恢复备份。
- **高级**：打开用户目录与日志，重新运行首次启动引导；不提供原始 YAML 补丁编辑。
- **关于**：版本、许可与第三方声明。

### 自定义短语

设置 › 自定义短语会把内容写入用户目录下的 `huma_custom.dict.yaml`。虎码主词典通过 `import_tables` 合并该表，因此改完几秒后新短语就会出现在候选中。编码必须手工填写虎码编码；权重可省略。

### 从其他输入法导入

概览页的「导入」可以只读导入鼠须管、小狼毫或 fcitx 的 RIME 目录：词库、自定义短语、配色与词频快照会复制到 Hufu 的独立用户目录，原目录不会被修改。方案与方案补丁不会导入——虎码方案由 Hufu 维护；如果导入的是拼音码表，需要自行把编码改成虎码后才能在候选里使用，界面中已有相应提示。

## 用户数据

| 路径 | 内容 |
| --- | --- |
| `~/Library/Hufu/Rime/` | librime 工作区：编译产物、用户词频、`hufu/imported`（手写补丁）、`hufu/generated`（设置写入层） |
| `~/Library/Logs/Hufu/` | librime 日志，默认 WARNING 级别，不记录输入内容 |

设置 App 不链接 librime，只读写配置层，并通过分布式通知请输入法应用改动（无需用户操作）。配置由三层合成：Hufu 默认值 → 手写补丁 → 设置修改。详见[架构说明](docs/architecture.md)与[决策记录](docs/decisions/)。

## 隐私

日常输入在本机由 librime 处理，按键路径不发起网络请求，不写输入日志，不上传编码串、候选或用户词频，也不包含遥测、崩溃上报或统计 SDK。

只有你主动执行 AI 动作时，目标文字才会交给所选模型：Apple 端侧模型在本机运行；若配置 OpenAI 兼容接口，需要单独允许发送文字，服务方可能计费。Hufu 不检查在线更新，也不在后台下载词库或模型。详见[隐私说明](docs/privacy.md)。

## 开发

```bash
bash scripts/fetch-librime.sh && bash scripts/stage-huma.sh
swift build --package-path Packages/HufuKit
swift test --package-path Packages/HufuKit
xcodegen generate && open Hufu.xcodeproj

# 性能门禁
swift build --package-path Packages/HufuKit -c release --product hufu
"$(swift build --package-path Packages/HufuKit -c release --show-bin-path)/hufu" bench \
  --schema tigress --keys tuja --iterations 2000 --assert-p99-ms 5
```

命令行工具 `hufu` 提供 `deploy / bench / doctor / diagnostics / import-squirrel / get / set / sync / register` 等子命令。贡献流程见 [CONTRIBUTING.zh.md](CONTRIBUTING.zh.md)，发布流程见 [docs/releasing.md](docs/releasing.md)，安全问题请按 [SECURITY.md](SECURITY.md) 私下报告。

## 文档

[文档导航](docs/README.md)汇总使用、配置、开发与分发说明。遇到问题请提交 [Issue](https://github.com/syhily/hufu/issues)。反馈请使用虚构文字，不要附带个人词频、完整输入记录或凭据。

## 致谢

[AIME](https://github.com/zoolapp/aime) · [RIME / librime](https://github.com/rime/librime) · [鼠须管](https://github.com/rime/squirrel) · [OpenCC](https://github.com/BYVoid/OpenCC) · [Yams](https://github.com/jpsim/Yams) · [swift-argument-parser](https://github.com/apple/swift-argument-parser) · [虎码官网](https://www.tiger-code.com)

## 许可与归属

Hufu 原创代码采用 [MIT](LICENSE) 许可，版权归 syhily 所有。项目基于 AIME（© 2026 ZOOL LLC，MIT）派生，保留原许可与署名。

安装包还包含：

- **librime 1.17.0**：BSD-3-Clause；静态链接自 [ghostflyby/librime-xcframework](https://github.com/ghostflyby/librime-xcframework) 的 `1.17.0-pack.10.0.0`（sha256 固定）。安装包不包含可动态加载的 librime 原生插件。
- **OpenCC 数据**：Apache-2.0。
- **虎码官方词库与方案**（虎码秃版 2026.08.15）：由虎码官方在 [tiger-code.com](https://www.tiger-code.com) 免费发布，经 [hufu-scheme](https://github.com/syhily/hufu-scheme) submodule（`dicts/huma`）引入。
- **Noto Sans SC**：SIL Open Font License 1.1，用于图标与品牌图形的字形轮廓。

发行包只包含 MIT / BSD / Apache / OFL 许可的组件与官方免费发布的数据，不含 GPL 组件，且不包含任何可动态加载的原生插件。第三方组件的完整清单见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)，发布核对项见[发布清单](docs/release-checklist.md)。

<p align="center"><sub>由 <a href="https://github.com/syhily">syhily</a> 发布与维护 · Hufu 与虎符输入法为 syhily 的产品名称</sub></p>

排障与诊断导出见[排障指南](docs/troubleshooting.md)。
