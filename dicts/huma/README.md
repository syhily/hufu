# 虎码秃版 鼠须管（Mac）定制裁剪版

本项目基于**虎码官方鼠须管（Squirrel）方案 2026.08.15 版本**的定制裁剪版，适用于 macOS 上的 Rime 输入法（鼠须管）。

它是[虎符输入法 Hufu](https://github.com/syhily/hufu) 的方案数据源，位于 Hufu 主仓库的 `dicts/huma` 目录（Hufu 内置 `tigress` 方案）。

## 包含方案

| 方案 | schema_id | 说明 |
| --- | --- | --- |
| 虎码官方单字 | `tiger` | 纯单字输出，无任何词组 |
| 虎码官方词库 | `tigress` | 单字 + 词组 |

两个方案均支持敲 `` ` `` 键进入拼音反查。

## 相对官方版本的定制内容

1. **拼音反查固定为小鹤双拼**
   官方版本提供自然码 / 小鹤 / 微软三种双拼反查配置，本版本仅保留小鹤双拼（`PY_c.custom.yaml`），其余方案的配置文件已移除。

2. **词组裁剪：去除 5 字及以上的超长词组**
   `tigress_ci.dict.yaml` 中删除了 4,785 条 5 字及以上词组，仅保留 2–4 字词：
   - 2 字词：83,654 条
   - 3 字词：17,635 条
   - 4 字词：24,366 条

3. **词表拆分与繁简词库**
   主表 `tigress.dict.yaml` 只保留单字与 `huma_custom`；词组移到
   `tigress_words_simp.dict.yaml`（默认启用）、`tigress_words_trad.dict.yaml`
   与 `tigress_words_tradown.dict.yaml`。后两者用独立 tag 停放，由产品层按简繁模式启用。

## 使用方法

1. 将本目录下所有文件复制到鼠须管的用户配置目录（`~/Library/Rime`）。
2. 在鼠须管菜单中执行「重新部署」（Deploy）。
3. 在 `default.custom.yaml` 中选择启用 `tiger`（纯单字）或 `tigress`（单字 + 词组）方案。

## 主要文件说明

- `tiger.schema.yaml` / `tiger.dict.yaml` — 单字方案与字表
- `tigress.schema.yaml` / `tigress.dict.yaml` — 词库方案；主表只含单字与 `huma_custom`，词组由独立词表 translator 提供
- `tigress_ci.dict.yaml` — 主词库源（已裁剪，仅 2–4 字词，125,655 条）
- `tigress_simp_ci.dict.yaml` — 高频简体词的短码补充（3,134 条）
- `tigress_words_simp.dict.yaml` — 合并后的简体词表（128,789 行 / 125,656 个词）；默认启用
- `tigress_words_trad.dict.yaml` — 打简出繁用：简体码 → 繁体词（128,786 行）
- `tigress_words_tradown.dict.yaml` — 只繁用：繁体码 → 繁体词（125,639 行）
- `tools/build_words.py` / `tools/words_report.txt` — 词表生成器与校验报告
- `core2022.dict.yaml` — 自定义字集工具方案
- `PY_c.schema.yaml` / `PY_c.custom.yaml` — 拼音反查方案（小鹤双拼）
- `easy_english.*` — 英文混输
- `stroke.*` — 笔画反查
- 不依赖 librime-lua；计算器、时间、大写数字等便利功能由 Hufu 前端原生实现

## 词表说明与再生成

`tigress.schema.yaml` 的 translators 中默认使用 `table_translator@words_simp`；
`table_translator@words_trad` 与 `table_translator@words_tradown` 分别停在
`words_trad` / `words_tradown` tag 上，产品层按简繁模式把对应 tag 改为 `abc`、
并停用 `words_simp` 后才会参与输入。三个 `.dict.yaml` 都随包发布。

词表由 `tigress_ci.dict.yaml` + `tigress_simp_ci.dict.yaml` 生成：

- `tigress_words_simp`：全量合并且只合并完全相同的 (text, code)，保留较大权重；简体词原样保留。
- `tigress_words_trad`：保留原简体 code/weight，文本经 OpenCC `st_tu.json`
  （STPhrases 词组级 + `STCharacters_Tu.txt` 异体）转换。
- `tigress_words_tradown`：文本同上转换，code 用 tigress 单字全码按 encoder 规则重算；
  任一繁体字无码的词会被丢弃并写入报告。

生成前主仓库需已有 `build/rime` 与 `build/SharedSupport`（先跑
`bash scripts/build-librime.sh`、`bash scripts/stage-huma.sh`）。在 `dicts/huma` 目录运行：

```bash
python3 tools/build_words.py \
  --opencc ../../build/rime/bin/opencc \
  --opencc-data ../../build/rime/share/opencc \
  --tu-table ../../build/SharedSupport/opencc/STCharacters_Tu.txt
```

参数都有相同的默认值；幂等，输出按权重/文本/编码固定排序，无时间戳。
校验结果（编码器自证、t2s 回译、逐字一致性、一简多繁风险词、只繁覆盖率、抽样）
写入 `tools/words_report.txt`。

## 上游

本仓库基于虎码官方发布的鼠须管方案（2026.08.15）修改，词库与编码规则版权归虎码官方所有。
