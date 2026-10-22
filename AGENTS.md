# AGENTS.md

Hufu 虎符输入法：macOS 输入法，librime 静态内嵌，只支持虎码（方案数据位于主仓库普通目录 `dicts/huma`）。

## 红线：不修改第三方组件

`Vendor/src/**` 的全部 submodule（librime、leveldb、marisa-trie、OpenCC、yaml-cpp）以及构建期下载的 Boost 源码包，**一律视为只读上游源码**：

- 禁止修改其源文件、CMakeLists、头文件；禁止在构建脚本里对其打补丁（`scripts/build-librime.sh` 现存的唯一补丁是历史例外，仅放开静态构建下的 tools 与 Boost.Regex 查找，不得在此基础上再增加）。
- 需要裁剪或改变行为时，只允许三种方式：
  1. **构建选项**：cmake `-D` 开关、编译/链接 flags（如 `ENABLE_LOGGING=OFF`、OpenCC `ENABLE_DARTS=OFF`、Release strip）；
  2. **消费方 shim**：在我们自己的代码里接管注册/链接行为（范例：`Vendor/hufu/gears_subset.cc` 的模块锚点截断 + Registry 白名单，见 `docs/decisions/0007-binary-trimming.md`）；
  3. **产品层封装**：在 `Packages/HufuKit`（RimeKit/HufuCore）或 Apps 层实现。
- 若某个需求只有修改三方源码才能实现：停下来，把取舍写进 `docs/decisions/` 并与人讨论，不要直接动手改 `Vendor/src`。

## 可复现构建

- 三方版本由 git submodule gitlink + `Vendor/librime.lock` 双重钉住；`scripts/build-librime.sh` 会校验每个 submodule 的 SHA，不一致直接拒绝构建。
- 首次构建：`git submodule update --init --recursive && bash scripts/build-librime.sh`（cmake、ninja 可选、Xcode 必备）。

## 验证入口（改动合入前必须通过）

```bash
swift test --package-path Packages/HufuKit --no-parallel   # 全量单元测试
python3 -m unittest discover -s scripts/tests              # 构建/许可证/白名单校验
bash scripts/stage-huma.sh                                 # 词典组装 + 预编译
bash scripts/check-rime-trim.sh <二进制>                    # 链接产物符号断言
```

## Git 纪律

- 不 amend 任何已存在的提交；修正用新的提交叠加。

## 决策记录

架构决策见 `docs/decisions/`（ADR-0001…0008），新增重要取舍时按序编号追加。
