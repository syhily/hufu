# ADR-0007：librime 组件子集与 Release 符号裁剪

- 状态：已接受 · 2026-10-22
- 关联：[ADR-0006](0006-in-tree-librime-build.md)

## 背景

librime 静态构建时，`src/rime_api.cc` 的 `rime_declare_module_dependencies()` 会显式
调用 `rime_require_module_gears()`，把 `gears_module.o` 拉进链接；该对象又实例化全部
34 个 gear 组件，导致所有 processor/segmentor/translator/filter/formatter 都进入 App。
Dead strip 无法切断这条从 `rime_api.cc` 出发的活引用。

Hufu 只使用虎码方案所需的一部分组件；其余组件既增加体积，也扩大攻击面。

## 决策

### 组件白名单

在消费方（Hufu）提供 `Vendor/hufu/gears_subset.cc`：

- 定义与 librime 同签名、同 C++ 链接名的 `void rime_require_module_gears() {}`。
  链接器因此不再从 `librime.a` 抽取 `gears_module.o`。
- `extern "C" hufu_rime_register_components()` 在 `RimeInitialize` 之前把白名单
  组件直接注册到 `rime::Registry`：
  - processors：`ascii_composer`, `recognizer`, `key_binder`, `speller`, `punctuator`,
    `selector`, `navigator`, `express_editor`, `shape_processor`
  - segmentors：`ascii_segmentor`, `matcher`, `affix_segmentor`, `abc_segmentor`,
    `punct_segmentor`, `fallback_segmentor`
  - translators：`punct_translator`, `table_translator`, `reverse_lookup_translator`,
    `history_translator`, `echo_translator`, `script_translator`,
    `schema_list_translator`, `switch_translator`
  - filters：`simplifier`（必须用 `SimplifierComponent`，不能用通用
    `Component<Simplifier>`）、`uniquifier`
  - formatters：`shape_formatter`
- `hufu_rime_check_components()` 用 `Registry::Find` 返回缺失数量，供 DEBUG 构建自检。

不注册的组件：`chord_composer`, `fluid_editor`, `fluency_editor`, `r10n_translator`,
`charset_filter`, `cjk_minifier`, `reverse_lookup_filter`, `single_char_filter`。
`Switcher` 需要的 `key_binder`/`selector`/`schema_list_translator`/`switch_translator`
以及 `Engine` 无条件创建的 `shape_processor`/`shape_formatter` 都在白名单中。

### 链接顺序

shim 的目标文件必须是 `libtool -static` 的**第一个**输入。若放在 `librime.a` 之后，
归档抽取会先选中 `gears_module.o`，stub 失效并退回全量链接。该顺序由
`scripts/build-librime.sh` 固定，不能随意调整。

### 静默失效风险与兜底

`Registry` 没有“注册失败”异常；`LoadModules` 对缺少的模块也静默跳过。因此：

1. `scripts/tests/test_rime_components.py` 解析 `build/SharedSupport/*.schema.yaml` 和
   `SharedSupport/default.yaml` 的 engine 列表（剥掉 `@tag`），与 shim 的
   `Register("...")` 集合对比。schema 用到但未注册 → 测试失败；注册但未使用 → warning。
2. DEBUG 构建在 `initialize` 后调用 `hufu_rime_check_components()`，缺失即
   `precondition` 失败。
3. CI 在 Debug App 构建后运行 `scripts/check-rime-trim.sh`，用 `nm -C` 断言禁用的
   组件类不存在、必需组件类存在。**CharsetFilter 是例外**：`TableTranslator` 直接引用
   `CharsetFilter::FilterDictEntry` 与 `CharsetFilterTranslation`，所以其符号会随
   `table_translator` 链入；它只是不注册，链接检查不应要求它消失。

### Release 符号裁剪

- Xcode 的 Release 配置开启 `DEPLOYMENT_POSTPROCESSING`、`STRIP_INSTALLED_PRODUCT`
  和 `STRIP_STYLE=all`；Hufu 与 Settings 都是 app 产品。
- `scripts/build-app.sh` 在 universal CLI `lipo` 之后、签名之前执行 `strip -x`。
- 签名在 strip 之后完成，避免破坏代码签名。

## 影响

- App/CLI 只链接白名单组件的实现；未注册组件的源文件不会从静态归档中被抽取。
- 新增方案或修改 engine 列表时，必须同步维护 shim；否则测试或 DEBUG 自检会失败。
- 不能通过 `Registry::Register` 注册的组件（例如需要特殊构造的 simplifier）必须显式
  使用其专用 Component 类。
- `rime_deployer` 等构建工具的链接方式不变；它们仍用于暂存词库。
