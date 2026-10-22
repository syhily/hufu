# ADR-0008：产品层四个深化模块

- 状态：已接受 · 2026-10-22

## 背景

近期的功能改动反复落在同一批摩擦上：

- 简繁四模式、词汇输入、标点和便利功能同时读写 `hufu/features.json` 与 `generated/` 补丁层，
  每个新开关都要在视图、`SettingsModel`、`SettingsStore` 和输入法之间重新决定“真值在哪”。
- 候选面板的前端候选、简繁排序/过滤、显示序号→rime 序号映射与 IMK 文本提交混在
  `HufuInputController.sync` 一个函数里，映射错误没有测试接缝。
- `ascii_mode`、`ascii_punct`、`simplification` 从四个入口写入，正确的顺序只存在于调用顺序；
  标点策略还从控制器直接读 librime 配置。
- 部署、导入、同步的排队与完成路径散在 `InputEngine` 的九个可变字段里，CLI 又重写了一遍
  策略；跨进程通知的字符串在两端各写一次。

## 决策

1. **`UserSettings`（HufuCore）** 是用户设置的单一句柄：读写 `features.json`，并在同一次调用里
   应用它推导出的 schema 挂载（词汇词表）。`SettingCatalog.Setting.validate` 是所有写入与 AI
   建议的唯一取值校验入口；OpenCC 标准由生成层拥有，`HufuFeatures.tradVariant` 只作为旧文件
   的回退。catalog 中重复的 `switches.ascii_punct` 与 `simplification.opencc_config` 条目删除：
   标点运行时状态由 `features.asciiPunct` 拥有，繁体标准只由「简繁」页的专用控件通过
   `UserSettings` 写入。
2. **`CandidatePresentation`（HufuPanel）** 拥有“这一页显示什么”和“显示序号意味着什么”：
   便利功能候选、简繁排序/过滤、标签、分页和高亮。控制器只保留 IMK 文本、草稿/上屏与事件适配。
3. **`InputOptions`（HufuCore）** 拥有会话选项决策：中文/英文状态、标点、简繁和 Caps Lock 撤销。
   控制器把会话当前值传入，应用返回的期望值；不再自行推导顺序。
4. **`DeployCoordinator`（HufuCore）** 拥有部署/导入/同步的排队、工作区锁、确认、导入快照随行
   和统一超时。`DeployDriver` 是进程侧适配器（librime、会话、候选窗）；CLI 与输入法共用
   `ConfigLayers.shippedTargets` 与 `DeployVerification` 判定成功。
5. **`DeployProtocol`（HufuCore）** 定义 `DeployRequest` / `DeployProgress` / `DeployReply` 与
   `DeployMode`。通知名和 `userInfo` 键保持原值，旧版本仍能互通；两端不再各自拼字符串。

## 边界

- 不改 `Vendor/src/**`；所有改动在产品层（HufuCore、HufuPanel、Apps）。
- 不改变 ADR-0002 的进程拓扑：仍然是文件 + 分布式通知，没有引入 XPC。
- 不改变 ADR-0003 的三层补丁格式：`UserSettings` 只是这些层的调用方。
- `CandidatePresentation` 的 `Input` 是普通值（候选文本、标签、页大小等），不依赖 RimeKit，
  因此 HufuPanel 的测试可以直接驱动它。

## 影响

- 新增/调整的测试：`CandidatePresentationTests`、`UserSettingsTests`、`InputOptionsTests`、
  `DeployCoordinatorTests`、`DeployProtocolTests`。
- 输入法与 CLI 现在用同一套“部署成功”判定：`schema_list` 中每个方案都必须有 build 产物。
- 设置页新增开关时，视图只调用 `SettingsModel` 的具名方法；schema 推导在 `UserSettings` 内完成。
