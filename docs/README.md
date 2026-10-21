# Hufu 文档 / Documentation

Hufu / 虎符输入法是基于 RIME 的开源 macOS 虎符输入法，只内置虎码方案，日常输入在本机处理，AI 按需参与。当前处于 0.1.x 早期发布；下载前请核对 [Release](https://github.com/syhily/hufu/releases) 的版本、校验文件与签名 / 公证说明。

Hufu is an open-source macOS input method built on RIME, with Tiger-Code as its only bundled schema, local input processing and optional AI. It is an early 0.1.x release; check the release notes, checksums and signing/notarization status before downloading.

| 你想做什么 / Goal | 入口 / Guide |
| --- | --- |
| 安装、启用与日常使用 / Install and use | [中文 README](../README.md) · [English README](../README.en.md) |
| 了解产品与迁移 / Product and migration | [中文 README](../README.md) · [English README](../README.en.md) |
| 调整输入习惯 / Configure typing | [RIME 配置参考](rime-config-reference.md) |
| 分享与自定义配色 / Themes | [主题说明](themes.md) |
| 排障与导出诊断信息 / Troubleshooting | [排障指南](troubleshooting.md) |
| 了解本地输入与 AI 边界 / Privacy and AI | [隐私说明](privacy.md) · [Security policy](../SECURITY.md) |
| 参与代码贡献 / Contribute code | [中文贡献指南](../CONTRIBUTING.zh.md) · [English contribution guide](../CONTRIBUTING.md) |
| 了解实现和取舍 / Architecture and decisions | [架构](architecture.md) · [决策记录](decisions/) |
| 构建与发布 / Build and release | [发布流程](releasing.md) · [发布清单](release-checklist.md) |
| 查看更新 / Changes | [CHANGELOG](../CHANGELOG.md) · [GitHub Releases](https://github.com/syhily/hufu/releases) |
| 核对源码与分发许可 / Source and distribution licenses | [原创代码 MIT](../LICENSE) · [第三方声明](../THIRD_PARTY_NOTICES.md) · [插件许可审查](native-plugin-license-audit.md) · [分发验证记录](license-packaging-verification.md) |

Hufu 原创代码采用 MIT 许可。安装包只带 `librime-lua` 一个原生插件，第三方组件为 MIT / BSD / Apache / OFL 许可，并包含虎码官方免费发布的词库与方案；发行包不含 GPL 组件。问题反馈使用虚构输入，不上传个人词频、完整输入记录或凭据。

Hufu's original code is MIT-licensed. The installer bundles a single native plugin, librime-lua; third-party components use MIT/BSD/Apache/OFL licences, and the Tiger-Code dictionary and schemas are officially free releases. The distribution contains no GPL components. Use synthetic input in reports and keep personal word frequencies, input history and credentials private.
