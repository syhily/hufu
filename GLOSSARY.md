# GLOSSARY 虎符领域词汇

本文件固定产品与架构讨论中的词义；实现位置以括号标注。架构通用词（module、interface、
seam、adapter、depth、leverage、locality）按 `/codebase-design` 的定义使用，不在这里重复。

## 输入与候选

- **方案（schema）**：librime 的一套输入方案（虎码为 `tigress`），由 `*.schema.yaml` 描述。
- **候选（candidate）**：一次按键后候选窗展示的可选项。rime 候选来自 librime；**前端候选**
  （frontend candidate）由 Hufu 自己生成，如 `/time`、`=1+2`、大写数字。
- **候选呈现（CandidatePresentation）**：把 rime 上下文、前端候选、简繁模式和页大小变成
  `PanelState` 的模块；同时拥有“显示序号 → rime 序号”的映射（`HufuPanel`）。
- **上屏（commit）**：把选中的文字写入客户端文本字段。
- **输入图层（draft layer）**：已上屏但停在光标前、等待确认的文字层（`DraftBuffer`）。
- **简繁四模式**：繁简混打、打简出繁、只打繁体、只打简体；存储值在 `features.json`，
  运行时由 `simplification` 选项和 `ScriptFilter` 表解析。
- **词汇输入**：按简繁模式挂载 `words_simp` / `words_trad` / `words_tradown` 三张词表；
  挂载规则由 `WordTables` 拥有。
- **便利功能**：时间日期、计算器、大写数字三类前端候选（`SpecialInput`）。

## 设置

- **用户设置（UserSettings）**：用户可见设置的单一句柄；跨 `hufu/features.json` 与
  `hufu/generated/*.yaml` 两个存储面，负责推导 schema 挂载（`HufuCore`）。
- **设置目录（catalog）**：`config/catalog.json` 描述的设置元数据；`SettingCatalog.Setting`
  拥有类型、范围和合法值校验。
- **补丁层（patch layers）**：defaults → imported → generated，后者覆盖前者，合成为
  `<name>.custom.yaml`；格式见 ADR-0003。

## 部署与同步

- **部署（deploy）**：重新合成补丁层、编译方案与前端配置、重建 build 产物。
- **增量部署（auto）**：设置改动后的自动部署；只改外观时可走前端配置快路径。
- **同步（sync）**：导出/合并用户词频快照；运行中的输入法持有 userdb，必须由它执行。
- **导入（import）**：只读复制鼠须管等 RIME 目录；词频快照在随后的部署之后合并。
- **部署协调（DeployCoordinator）**：拥有部署/导入/同步的队列、工作区锁、完成确认、导入随行
  和超时（`HufuCore`）。
- **工作区锁（WorkspaceLock）**：跨进程 flock，保证同一用户目录只有一个写入者。
