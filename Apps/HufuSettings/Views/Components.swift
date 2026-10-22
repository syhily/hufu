import HufuCore
import HufuPanel
import AppKit
import SwiftUI

/// Large page title with a one-line explanation, shared by every pane.
struct PaneHeader: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let symbol: String

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 38, height: 38)
                .foregroundStyle(.white)
                .background(Theme.iconTile, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.text)
                Text(subtitle).font(.callout).foregroundStyle(Theme.secondaryText).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, 2)
        .containerValue(\.isPlain, true)
    }
}

/// A catalog-driven form pane (输入习惯 / 中英切换 / 快捷键).
struct CatalogPane: View {
    @Environment(SettingsModel.self) private var model
    let pane: Pane

    var subtitle: LocalizedStringKey {
        switch pane {
        case .general: "候选词数量、方案选单、简繁、便利功能与虎码开关。"
        case .switching: "Caps Lock 与 Shift 在输入中的行为，以及中英文切换方式。"
        case .keys: "快捷菜单与方案选单的触发方式，以及翻页键。"
        default: ""
        }
    }

    var body: some View {
        let settings = model.catalog.settings(in: pane.catalogGroup ?? "")
            .filter { $0.type != .custom }
        Form {
            Section { PaneHeader(title: pane.title, subtitle: subtitle, symbol: pane.symbol) }

            if pane == .general {
                ScriptSection()
                PunctuationSection()
                ConvenienceSection()
            }
            if pane == .keys {
                QuickMenuShortcutsSection()
                Section("方案选单") {
                    ForEach(settings.filter { $0.id == "switcher.hotkeys" }) { SettingRow(setting: $0) }
                }
                Section("选词、翻页与输入开关") {
                    ForEach(settings.filter { $0.id != "switcher.hotkeys" }) { SettingRow(setting: $0) }
                }
            } else {
                Section {
                    ForEach(settings) { setting in SettingRow(setting: setting) }
                }
            }
        }
        .formStyle(.cards)
    }

}

/// Trigger behavior belongs with shortcuts; the candidate button's visibility stays
/// in Appearance. Uses the existing features save/notification channel.
private struct QuickMenuShortcutsSection: View {
    @Environment(SettingsModel.self) private var model

    var body: some View {
        Section {
            LabeledContent {
                Picker("快捷菜单长按键", selection: Binding(
                    get: { model.features.menuHoldKey },
                    set: { key in model.updateFeatures { $0.menuHoldKey = key } }
                )) {
                    Text("⌥ Option（左右均可）").tag(ModifierHold.Key.option)
                    Text("左 ⌥ Option").tag(ModifierHold.Key.optionLeft)
                    Text("右 ⌥ Option").tag(ModifierHold.Key.optionRight)
                    Text("⌃ Control（左右均可）").tag(ModifierHold.Key.control)
                    Text("左 ⌃ Control").tag(ModifierHold.Key.controlLeft)
                    Text("右 ⌃ Control").tag(ModifierHold.Key.controlRight)
                    Text("⌘ Command（左右均可）").tag(ModifierHold.Key.command)
                    Text("左 ⌘ Command").tag(ModifierHold.Key.commandLeft)
                    Text("右 ⌘ Command").tag(ModifierHold.Key.commandRight)
                    Text("关闭").tag(ModifierHold.Key.off)
                }
                .labelsHidden()
                .fixedSize()
                .accessibilityLabel("快捷菜单长按键")
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("长按触发键")
                    Text("打字时单独按住约 0.35 秒，打开常用语、符号和表情菜单；与其他键组合时不触发。")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            LabeledContent("组合键打开", value: "⌃⌥M（固定）")
        } header: {
            Text("快捷菜单")
        } footer: {
            Text("关闭长按后仍可用 ⌃⌥M 打开。方案选单是切换输入方案和开关的菜单，触发键在下方单独设置。")
        }
    }
}

/// Chinese / English punctuation, shared by all apps (#10).
private struct PunctuationSection: View {
    @Environment(SettingsModel.self) private var model

    var body: some View {
        Section {
            LabeledContent {
                Picker("", selection: Binding(get: { model.asciiPunct }, set: { model.setAsciiPunct($0) })) {
                    Text("中文标点").tag(false)
                    Text("英文标点").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .padding(.trailing, 28) // lines up with catalog rows (their reset-button slot)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text("中文输入时的标点")
                    Text("所有 App 共用：打字时按 ⌃. 切换，其他 App 也跟着变。输入法启动时用这里的选择；「记忆的开关」里勾选了英文标点时，沿用上次的状态。")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        } header: {
            Text("标点")
        }
    }
}

/// 简繁四模式, and the OpenCC standard that 打简出繁 / 只打繁体 convert with.
private struct ScriptSection: View {
    @Environment(SettingsModel.self) private var model

    /// Every OpenCC standard the catalog offers, with the product's labels.
    private static let variants = [
        ("st_tu.json", "虎码标准"),
        ("s2t.json", "通用繁体"),
        ("s2tw.json", "台湾正体"),
        ("s2twp.json", "台湾正体（含常用词）"),
        ("s2hk.json", "香港繁体"),
    ]

    var body: some View {
        Section {
            LabeledContent {
                Picker("", selection: Binding(
                    get: { model.scriptMode },
                    set: { model.setScriptMode($0) }
                )) {
                    Text("繁简混打").tag(ScriptMode.mixed)
                    Text("打简出繁").tag(ScriptMode.tradOutput)
                    Text("只打繁体").tag(ScriptMode.tradOnly)
                    Text("只打简体").tag(ScriptMode.simpOnly)
                }
                .labelsHidden()
                .fixedSize()
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text("简繁模式")
                    Text(explanation).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.trailing, 28) // lines up with catalog rows (their reset-button slot)

            LabeledContent {
                Picker("", selection: variant) {
                    ForEach(Self.variants, id: \.0) { value, title in Text(title).tag(value) }
                }
                .labelsHidden()
                .fixedSize()
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text("繁体标准")
                    Text("转换用的 OpenCC 字表，改完几秒后自动生效；对繁简混打和只打简体没有影响。")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.trailing, 28)
            .disabled(!model.scriptMode.usesTraditionalConversion)

            Toggle(isOn: Binding(
                get: { model.wordsEnabled },
                set: { model.setWordsEnabled($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("词汇输入")
                    Text(wordsDetail).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } header: {
            Text("简繁")
        } footer: {
            Text("打字时 ⌃O 或 ⌃⇧4 临时切换：繁简混打 ↔ 打简出繁，只打简体 ↔ 只打繁体；下次启动回到这里的设置。临时切换只影响单字，词汇词表仍按这里的模式挂载。已经打出的文字：选中或刚打完后按 ⌃⌥P，选「简繁转换」，在本机转换，不经过 AI。")
        }
    }

    /// The copy follows the switch, then names the tables the current mode mounts.
    private var wordsDetail: LocalizedStringKey {
        guard model.wordsEnabled else {
            return "关闭时只出单字和自定义短语；打开后按简繁模式挂载对应词表，改完几秒后自动生效。"
        }
        switch model.scriptMode {
        case .mixed: return "已挂载简体词表与繁体编码词表：简码出简体词，繁体字自己的编码出繁体词。"
        case .tradOutput: return "已挂载打简出繁词表：简体编码直接出校验过的繁体词。"
        case .tradOnly: return "已挂载只繁词表：用繁体字自己的编码出繁体词。"
        case .simpOnly: return "已挂载简体词表：只出《通用规范汉字表》内的词。"
        }
    }

    private var explanation: LocalizedStringKey {
        switch model.scriptMode {
        case .mixed: "简体优先：按《通用规范汉字表》一级→二级→三级排序，繁体字形排在最后。"
        case .tradOutput: "用简体编码打字，候选直接是繁体；候选同样限定在 8105 字集内。"
        case .tradOnly: "只出繁体；转换后仍带简体字形的候选会被过滤。"
        case .simpOnly: "只出《通用规范汉字表》里的简体字，繁体字形和表外生僻字不显示。"
        }
    }

    /// The standard is owned by the generated layer (`simplification/opencc_config`);
    /// `UserSettings` handles the read and the write.
    private var variant: Binding<String> {
        Binding(
            get: {
                let stored = model.scriptVariant
                return Self.variants.contains(where: { $0.0 == stored }) ? stored : "st_tu.json"
            },
            set: { model.setScriptVariant($0) }
        )
    }
}

/// 便利功能: candidates the input method makes itself, in place of the old lua translators.
private struct ConvenienceSection: View {
    @Environment(SettingsModel.self) private var model

    var body: some View {
        Section {
            toggle("时间与日期",
                   detail: "打 /time 取时间，/date 取日期，/week 取星期，/cdate 取农历；也收 /fsj、/frq、/fxq、/fnl 等虎码谐音。",
                   keyPath: \.dateTimeCandidates)
            toggle("计算器",
                   detail: "以 = 开头算数，如 =1+2*3、(1+2)/4、=10%3，选词即上屏结果。",
                   keyPath: \.calculatorCandidates)
            toggle("大写数字",
                   detail: "打 / 加数字，如 /1234.56，给出大写、小写和元角分写法。",
                   keyPath: \.numeralsCandidates)
        } header: {
            Text("便利功能")
        } footer: {
            Text("这几种输入由输入法直接给出候选，不经过词典；关掉后不再提供候选，按键交回方案处理。")
        }
    }

    private func toggle(_ title: LocalizedStringKey, detail: LocalizedStringKey,
                        keyPath: WritableKeyPath<HufuFeatures, Bool>) -> some View {
        Toggle(isOn: Binding(
            get: { model.features[keyPath: keyPath] },
            set: { on in model.updateFeatures { $0[keyPath: keyPath] = on } }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Renders the right control for a catalog setting and writes changes back.
struct SettingRow: View {
    @Environment(SettingsModel.self) private var model
    let setting: SettingCatalog.Setting

    var body: some View {
        let customized = model.isCustomized(setting)
        LabeledContent {
            // Every control ends on the same trailing line: the reset button has a
            // fixed slot whether or not it is shown.
            HStack(spacing: 10) {
                control
                ZStack {
                    if customized {
                        Button {
                            model.reset(setting)
                        } label: {
                            Image(systemName: "arrow.uturn.backward.circle.fill").foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.borderless)
                        .help("恢复为导入或默认值")
                    }
                }
                .frame(width: 18)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(setting.title)
                    if customized {
                        Circle().fill(Theme.accent).frame(width: 6, height: 6).help("已自定义")
                    }
                }
                if let description = setting.description, !description.isEmpty {
                    Text(description).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var control: some View {
        let current = model.value(setting)
        switch setting.type {
        case .bool: boolControl(current)
        case .int: intControl(current)
        case .double:
            let value = current?.doubleValue ?? setting.default?.doubleValue ?? 0
            if let steps = setting.options, !steps.isEmpty {
                // A few fixed sizes (font sizes): stepped "A" control instead of a free number.
                SizeStepControl(steps: steps.compactMap { step in step.value.doubleValue.map { ($0, step.title) } },
                                range: setting.min.flatMap { min in setting.max.map { min...$0 } }, value: value) {
                    model.set(.double($0), for: setting)
                }
            } else {
                DoubleControl(setting: setting, value: value)
            }
        case .enum: enumControl(current)
        case .font: FontPicker(value: current?.stringValue ?? "") { model.set(.string($0), for: setting) }
        case .color: colorControl(current)
        case .stringList: listControl(current)
        case .hotkey:
            let key = current?.stringValue ?? ""
            HStack(spacing: 4) {
                KeyRecorder(value: key) { model.set(.string($0), for: setting) }
                // Fixed slot so recorders line up whether or not the key is set.
                ZStack {
                    if !key.isEmpty {
                        Button {
                            model.set(.string(""), for: setting)
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .help("清除快捷键")
                        .accessibilityLabel("清除快捷键")
                    }
                }
                .frame(width: 18)
            }
        case .hotkeyList:
            HotkeyListControl(values: (current?.listValue ?? []).compactMap(\.stringValue)) {
                model.set(.list($0.map(ConfigValue.string)), for: setting)
            }
        case .switchList:
            SwitchListControl(
                selected: (current?.listValue ?? []).compactMap(\.stringValue),
                available: model.availableSwitches
            ) { model.set(.list($0.map(ConfigValue.string)), for: setting) }
        case .string: textControl(current)
        case .custom: EmptyView()
        }
    }

    private func boolControl(_ current: ConfigValue?) -> some View {
        let binding = Binding<Bool>(get: { current?.boolValue ?? false }, set: { model.set(.bool($0), for: setting) })
        return Toggle("", isOn: binding).labelsHidden().toggleStyle(.switch)
    }

    private func intControl(_ current: ConfigValue?) -> some View {
        let value: Int = current?.intValue ?? setting.default?.intValue ?? 0
        let range: ClosedRange<Int> = Int(setting.min ?? 0)...Int(setting.max ?? 99)
        let binding = Binding<Int>(get: { value }, set: { model.set(.int($0), for: setting) })
        return HStack(spacing: 6) {
            Text("\(value)").monospacedDigit().font(.body.weight(.medium)).frame(minWidth: 24, alignment: .trailing)
            Stepper("", value: binding, in: range).labelsHidden()
        }
    }

    private func enumControl(_ current: ConfigValue?) -> some View {
        let options: [SettingCatalog.Option] = setting.options ?? []
        let fallback: ConfigValue = setting.default ?? options.first?.value ?? .null
        let binding = Binding<ConfigValue>(get: { current ?? fallback }, set: { model.set($0, for: setting) })
        // Segments only for a few short labels; long ones would be clipped at narrow widths.
        let segmented = options.count <= 3 && options.map(\.title.count).reduce(0, +) <= 12
        return Picker("", selection: binding) {
            ForEach(options) { option in Text(option.title).tag(option.value) }
        }
        .labelsHidden()
        .adaptivePickerStyle(segmented: segmented)
        .fixedSize()
    }

    private func colorControl(_ current: ConfigValue?) -> some View {
        let color: ThemeColor = ThemeColor(rime: current, format: "argb") ?? .clear
        let binding = Binding<Color>(
            get: { Color(themeColor: color) },
            set: { model.set(.string(ThemeColor(color: $0).argbString), for: setting) }
        )
        return ColorPicker("", selection: binding, supportsOpacity: true).labelsHidden()
    }

    private func listControl(_ current: ConfigValue?) -> some View {
        let text: String = (current?.listValue ?? []).compactMap(\.stringValue).joined(separator: ", ")
        return CommitTextField(value: text, placeholder: "用逗号分隔") { text in
            let items: [String] = text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            model.set(.list(items.map(ConfigValue.string)), for: setting)
        }
    }

    private func textControl(_ current: ConfigValue?) -> some View {
        let placeholder = setting.type == .hotkey ? "如 Control+grave" : ""
        return CommitTextField(value: current?.stringValue ?? "", placeholder: placeholder) { model.set(.string($0), for: setting) }
    }
}

extension View {
    /// Segmented for a few options, menu otherwise.
    @ViewBuilder
    func adaptivePickerStyle(segmented: Bool) -> some View {
        if segmented { pickerStyle(.segmented) } else { pickerStyle(.menu) }
    }
}

/// Slider for bounded doubles, stepper-backed text field otherwise.
struct DoubleControl: View {
    @Environment(SettingsModel.self) private var model
    let setting: SettingCatalog.Setting
    let value: Double
    @State private var draft: Double?

    var body: some View {
        if let min = setting.min, let max = setting.max {
            HStack(spacing: 8) {
                Slider(value: Binding(get: { draft ?? value }, set: { draft = $0 }), in: min...max) { editing in
                    if !editing, let draft {
                        model.set(.double((draft * 100).rounded() / 100), for: setting)
                        self.draft = nil
                    }
                }
                .frame(width: 160)
                Text((draft ?? value).formatted(.number.precision(.fractionLength(0...2))))
                    .monospacedDigit().foregroundStyle(.secondary).frame(width: 36, alignment: .trailing)
            }
        } else {
            TextField("", value: Binding(get: { value }, set: { model.set(.double($0), for: setting) }), format: .number)
                .frame(width: 80)
                .multilineTextAlignment(.trailing)
        }
    }
}

/// Five (or so) preset sizes shown as letters of growing size, with a sliding selection —
/// like the text-size control of a reader app — plus a ±1 pt stepper for a custom size within
/// `range` (#7). Whole points only.
struct SizeStepControl: View {
    let steps: [(value: Double, title: String)]
    /// Bounds for the custom stepper; without them only the presets are offered.
    var range: ClosedRange<Double>? = nil
    let value: Double
    let commit: (Double) -> Void
    @Namespace private var selection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The preset matching the value; nil for a custom size.
    private var selectedIndex: Int? {
        steps.firstIndex { $0.value == value.rounded() }
    }

    var body: some View {
        let selected = selectedIndex ?? -1
        HStack(spacing: 10) {
            let points = "\(Int(value.rounded())) pt"
            // Narrow windows drop the preset name rather than clip the label.
            ViewThatFits(in: .horizontal) {
                Text(selectedIndex.map { "\(steps[$0].title) · \(points)" } ?? (range == nil ? points : "自定义 · \(points)"))
                Text(points)
            }
            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            .lineLimit(1)
            .contentTransition(.numericText())
            HStack(spacing: 0) {
                ForEach(steps.indices, id: \.self) { index in
                    Button {
                        commit(steps[index].value)
                    } label: {
                        Text("A")
                            .font(.system(size: 10.5 + CGFloat(index) * 2.4, weight: index == selected ? .semibold : .regular))
                            .foregroundStyle(index == selected ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                            .frame(width: 34, height: 28)
                            .background {
                                if index == selected {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Theme.card)
                                        .shadow(color: .black.opacity(0.12), radius: 1.5, y: 0.5)
                                        .matchedGeometryEffect(id: "selection", in: selection)
                                }
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("\(steps[index].title) · \(Int(steps[index].value)) pt")
                    .accessibilityLabel("\(steps[index].title)，\(Int(steps[index].value)) 磅")
                    .accessibilityAddTraits(index == selected ? .isSelected : [])
                }
            }
            .padding(2)
            .background(Theme.divider, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: selected)
            if let range {
                Stepper("", value: Binding(
                    get: { min(max(value.rounded(), range.lowerBound), range.upperBound) },
                    set: { commit(min(max($0, range.lowerBound), range.upperBound)) }
                ), in: range, step: 1)
                .labelsHidden()
                .help("自定义字号（\(Int(range.lowerBound))–\(Int(range.upperBound)) pt）")
                .accessibilityLabel("自定义字号")
                .accessibilityValue("\(Int(value.rounded())) 磅")
            }
        }
    }
}

/// Text field that writes on submit / focus loss instead of per keystroke.
struct CommitTextField: View {
    let value: String
    var placeholder: String = ""
    /// Widest the field may get (`.infinity` for long values such as prompts).
    var maxWidth: CGFloat = 260
    let commit: (String) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        // Title-less field with a prompt: in a macOS Form the title would render as a
        // trailing label next to the control.
        TextField("", text: $text, prompt: placeholder.isEmpty ? nil : Text(placeholder))
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .frame(minWidth: 180, maxWidth: maxWidth)
            .focused($focused)
            .onAppear { text = value }
            .onChange(of: value) { _, new in if !focused { text = new } }
            .onSubmit { if text != value { commit(text) } }
            .onChange(of: focused) { _, isFocused in if !isFocused, text != value { commit(text) } }
    }
}

/// Font family picker with a curated list of CJK-capable faces plus free text.
struct FontField: View {
    let value: String
    let commit: (String) -> Void

    static let suggestions: [String] = {
        let preferred = ["PingFang SC", "Hiragino Sans GB", "Songti SC", "Kaiti SC", "LXGW WenKai", "Source Han Sans SC",
                         "Noto Sans CJK SC", "Sarasa Gothic SC", "SF Pro", "SF Pro Rounded", "Helvetica Neue", "Menlo"]
        let installed = Set(NSFontManager.shared.availableFontFamilies)
        return preferred.filter { installed.contains($0) || $0.hasPrefix("SF Pro") }
    }()

    var body: some View {
        HStack(spacing: 6) {
            CommitTextField(value: value, placeholder: "字体名称", commit: commit)
            Menu {
                ForEach(Self.suggestions, id: \.self) { name in
                    Button(name) { commit(name) }
                }
            } label: {
                Image(systemName: "textformat")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }
}

extension Color {
    init(themeColor: ThemeColor) {
        self.init(.sRGB, red: themeColor.red, green: themeColor.green, blue: themeColor.blue, opacity: themeColor.alpha)
    }
}

extension ThemeColor {
    init(color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .black
        self.init(red: ns.redComponent, green: ns.greenComponent, blue: ns.blueComponent, alpha: ns.alphaComponent)
    }
}

/// Hosts the real AppKit candidate view so the preview matches the input method exactly.
struct PanelPreview: NSViewRepresentable {
    let theme: PanelTheme
    var state: PanelState = .sample

    func makeNSView(context: Context) -> CandidateView {
        let view = CandidateView()
        view.forcePreedit = true
        return view
    }

    func updateNSView(_ view: CandidateView, context: Context) {
        view.theme = theme
        view.state = state
        view.forcePreedit = true
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: CandidateView, context: Context) -> CGSize? {
        nsView.fittingContentSize
    }
}
