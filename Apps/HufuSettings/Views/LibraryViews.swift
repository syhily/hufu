import HufuCore
import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Apps

struct AppOptionsView: View {
    @Environment(SettingsModel.self) private var model

    var body: some View {
        Form {
            Section { PaneHeader(title: "应用", subtitle: "为编程类等应用设置默认英文（首次进入为英文，之后记住你在该应用里的选择，不影响其他应用）、关闭内联预编辑或启用 Vim 模式。", symbol: "square.grid.2x2") }

            Section { SmartSetupCard() }

            Section(model.appOptions.isEmpty ? "" : "已配置的应用") {
                ForEach(model.appOptions) { option in
                    AppOptionRow(option: option)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                Button {
                    chooseApp()
                } label: {
                    Label("手动添加应用…", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }
        }
        .formStyle(.cards)
        .animation(.snappy(duration: 0.3), value: model.appOptions)
        // `--smart-setup` (UI acceptance): run the scan right away.
        .task { if ProcessInfo.processInfo.arguments.contains("--smart-setup") { await model.scanInstalledApps() } }
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "添加"
        guard panel.runModal() == .OK, let url = panel.url, let bundleID = Bundle(url: url)?.bundleIdentifier else { return }
        model.setAppOption(.init(bundleID: bundleID, initialMode: .english))
    }
}

/// 智能配置: scan installed apps → review the recommended options → apply.
private struct SmartSetupCard: View {
    @Environment(SettingsModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch model.appScanPhase {
            case .idle:
                header(title: "智能配置", detail: "扫描已安装的应用，按推荐方案配好：终端、代码编辑器和启动器默认英文，Vim 类编辑器开启 Vim 模式。确认后才会写入，不会改动已有设置。") {
                    Button("开始扫描") { Task { await model.scanInstalledApps() } }.buttonStyle(.borderedProminent)
                }
            case let .scanning(fraction, name, path):
                header(title: "正在扫描已安装的应用…", detail: name.isEmpty ? "准备中" : name) { EmptyView() }
                HStack(spacing: 12) {
                    Group {
                        if let path { Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable() }
                        else { Image(systemName: "app.dashed").resizable().foregroundStyle(.tertiary) }
                    }
                    .frame(width: 28, height: 28)
                    .id(path)
                    .transition(reduceMotion ? .opacity : .asymmetric(insertion: .scale(scale: 0.7).combined(with: .opacity), removal: .opacity))
                    ProgressView(value: fraction).progressViewStyle(.linear).tint(Theme.accent)
                    Text("\(Int(fraction * 100))%").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 36, alignment: .trailing)
                }
                .animation(.easeOut(duration: 0.12), value: path)
                .animation(.linear(duration: 0.08), value: fraction)
            case .review:
                review
            case let .applied(count):
                header(title: count == 0 ? "没有需要新增的配置" : "已配置 \(count) 个应用",
                       detail: count == 0 ? "" : "已自动应用到输入法，可在下方逐个调整。", symbol: "checkmark.circle.fill", tint: Theme.success) {
                    Button("重新扫描") { Task { await model.scanInstalledApps() } }
                }
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.28), value: phaseKey)
    }

    /// Animates phase changes, not every progress tick.
    private var phaseKey: Int {
        switch model.appScanPhase {
        case .idle: 0
        case .scanning: 1
        case .review: 2
        case .applied: 3
        }
    }

    private func header<Trailing: View>(title: String, detail: String, symbol: String = "wand.and.stars", tint: Color = Theme.accent,
                                        @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: symbol).font(.title2).foregroundStyle(tint).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.medium))
                if !detail.isEmpty {
                    Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).lineLimit(2)
                }
            }
            Spacer(minLength: 12)
            trailing()
        }
        .transition(.opacity)
    }

    @ViewBuilder private var review: some View {
        let suggestions = model.appSuggestions
        let selected = suggestions.filter(\.selected).count
        if suggestions.isEmpty {
            header(title: "没有新的推荐", detail: "已安装的应用都已按推荐配置，或不需要特殊处理。", symbol: "checkmark.circle.fill", tint: Theme.success) {
                Button("完成") { model.dismissAppScan() }
            }
        } else {
            let confident = suggestions.filter { $0.rule.selectedByDefault != false }.count
            let optional = suggestions.count - confident
            header(title: "找到 \(confident) 个推荐配置" + (optional > 0 ? "，另有 \(optional) 个可选" : ""),
                   detail: "已按推荐预先选好中文或英文，可以逐个修改；只应用勾选的项。") {
                Button("取消") { model.dismissAppScan() }
                Button("应用 \(selected) 项") { model.applyAppSuggestions() }.buttonStyle(.borderedProminent).disabled(selected == 0)
            }
            let rules = suggestions.reduce(into: [AppRecommendations.Rule]()) { list, item in
                if !list.contains(where: { $0.id == item.rule.id }) { list.append(item.rule) }
            }
            ForEach(rules) { rule in
                let items = suggestions.filter { $0.rule.id == rule.id }
                Group {
                    if rule.selectedByDefault == false {
                        // Broad, opt-in matches stay folded so the confident ones lead.
                        DisclosureGroup {
                            SuggestionList(items: items).padding(.top, 6)
                        } label: {
                            HStack(spacing: 6) {
                                Text("\(rule.title)（\(items.count) 个，可选）").font(.caption.weight(.semibold))
                                Text(rule.reason).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Text(rule.title).font(.caption.weight(.semibold))
                                Text(rule.reason).font(.caption).foregroundStyle(.secondary)
                            }
                            SuggestionList(items: items)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

/// One scanned app: tick, icon, name, and the mode it will start in — prefilled with the
/// recommendation and editable before applying.
struct SuggestionRow: View {
    @Environment(SettingsModel.self) private var model
    let suggestion: AppRecommendations.Suggestion

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(get: { suggestion.selected }, set: { _ in model.toggleAppSuggestion(suggestion.id) }))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .accessibilityLabel("应用到 \(suggestion.app.name)")
            Group {
                if let url = suggestion.app.url { Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable() }
                else { Image(systemName: "magnifyingglass.circle.fill").resizable().foregroundStyle(.secondary) }
            }
            .frame(width: 24, height: 24)
            Text(suggestion.app.name).lineLimit(1)
            if !extras.isEmpty { Text(extras).font(.caption).foregroundStyle(.secondary) }
            Spacer(minLength: 8)
            Picker("", selection: Binding(get: { suggestion.initialMode }, set: { model.setAppSuggestionMode(suggestion.id, $0) })) {
                Text("中文").tag(SettingsStore.AppOption.InitialMode.chinese)
                Text("英文").tag(SettingsStore.AppOption.InitialMode.english)
                Text("跟随全局").tag(SettingsStore.AppOption.InitialMode.shared)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .accessibilityLabel("\(suggestion.app.name) 进入时的输入状态")
        }
        .labeledContentStyle(.automatic)
        .padding(.vertical, 5)
        .opacity(suggestion.selected ? 1 : 0.62)
    }

    private var extras: String {
        var parts: [String] = []
        if suggestion.option.vimMode { parts.append("Vim 模式") }
        if suggestion.option.noInline { parts.append("不内联") }
        return parts.joined(separator: " · ")
    }
}

/// Rows of one rule as a list with hairlines between them.
private struct SuggestionList: View {
    let items: [AppRecommendations.Suggestion]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("应用").padding(.leading, 62)
                Spacer()
                Text("进入时默认")
            }
            .font(.caption2).foregroundStyle(.tertiary)
            .padding(.bottom, 2)
            ForEach(items) { item in
                Divider().opacity(0.5)
                SuggestionRow(suggestion: item)
            }
        }
    }
}

private struct AppOptionRow: View {
    @Environment(SettingsModel.self) private var model
    let option: SettingsStore.AppOption

    var body: some View {
        let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: option.bundleID)
        HStack(spacing: 12) {
            Image(nsImage: appURL.map { NSWorkspace.shared.icon(forFile: $0.path) } ?? NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil)!)
                .resizable().frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(appURL.map { FileManager.default.displayName(atPath: $0.path).replacingOccurrences(of: ".app", with: "") } ?? option.bundleID)
                Text(option.bundleID).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            // Compact checkboxes keep their own layout (not the card's label/content rows).
            Group {
                Picker("", selection: Binding(get: { option.initialMode }, set: { value in
                    var updated = option
                    updated.initialMode = value
                    model.setAppOption(updated)
                })) {
                    Text("默认英文").tag(SettingsStore.AppOption.InitialMode.english)
                    Text("默认中文").tag(SettingsStore.AppOption.InitialMode.chinese)
                    Text("跟随全局").tag(SettingsStore.AppOption.InitialMode.shared)
                }
                .labelsHidden()
                .fixedSize()
                Toggle("不内联", isOn: binding(\.noInline))
                Toggle("Vim", isOn: binding(\.vimMode))
            }
            .toggleStyle(.checkbox)
            .labeledContentStyle(.automatic)
            .fixedSize()
            Button(role: .destructive) { model.removeAppOption(option.bundleID) } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless)
        }
    }

    private func binding(_ keyPath: WritableKeyPath<SettingsStore.AppOption, Bool>) -> Binding<Bool> {
        Binding(get: { option[keyPath: keyPath] }, set: { value in
            var updated = option
            updated[keyPath: keyPath] = value
            model.setAppOption(updated)
        })
    }
}

// MARK: - Dictionaries

struct DictionariesView: View {
    @Environment(SettingsModel.self) private var model

    private var singleCharacters: Int {
        model.baseDictionaryMetadata?.sourceFiles.first { $0.path == "tigress.dict.yaml" }?.rawRows ?? 0
    }

    private var phrases: Int {
        model.baseDictionaryMetadata?.sourceFiles
            .filter { $0.path == "tigress_ci.dict.yaml" || $0.path == "tigress_simp_ci.dict.yaml" }
            .reduce(0) { $0 + $1.rawRows } ?? 0
    }

    var body: some View {
        Form {
            Section {
                PaneHeader(title: "词库", subtitle: "内置虎码官方词库；自定义短语在「自定义短语」页维护。", symbol: "books.vertical")
            }

            Section {
                if let metadata = model.baseDictionaryMetadata {
                    LabeledContent {
                        Text(metadata.sourceVersion).font(.caption.monospaced()).foregroundStyle(.secondary)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(metadata.sourceName).font(.body.weight(.medium))
                            Text("虎码官方秃版 · \(metadata.license)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    LabeledContent("单字") {
                        Text(singleCharacters.formatted()).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    LabeledContent("词组") {
                        Text(phrases.formatted()).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    LabeledContent("词条记录") {
                        Text("\(metadata.rawRows.formatted()) 条（未去重）")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    if let page = URL(string: "https://www.tiger-code.com") {
                        Link(destination: page) { Label("虎码官网", systemImage: "arrow.up.right.square") }
                            .font(.caption)
                    }
                } else {
                    Text("词库信息不可用。改动任意设置后会自动生成。")
                        .font(.callout).foregroundStyle(.secondary)
                }
            } header: {
                Text("内置虎码词库")
            } footer: {
                Text("自定义短语在「自定义短语」页维护，写入 huma_custom.dict.yaml 并合并进虎码主词库，改完几秒后自动生效。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.cards)
        .scrollTargetForScreenshots()
    }
}

// MARK: - Phrases

struct PhrasesView: View {
    @Environment(SettingsModel.self) private var model
    @State private var search = ""
    @State private var newText = ""
    @State private var newCode = ""
    @State private var selection = Set<CustomPhrases.Phrase.ID>()

    private var squirrelPhraseTable: URL {
        HufuPaths.squirrelUserDir.appendingPathComponent("custom_phrase.txt")
    }

    var body: some View {
        @Bindable var model = model
        let filtered = model.phrases.phrases.filter {
            search.isEmpty || $0.text.localizedCaseInsensitiveContains(search) || $0.code.contains(search.lowercased())
        }
        VStack(alignment: .leading, spacing: 14) {
            PaneHeader(title: "自定义短语", subtitle: "编码为虎码，如 虎码=zhmn、你好=jxbh；权重可省略。修改后自动生效。", symbol: "text.quote")
            HStack(spacing: 10) {
                Text("短语表 huma_custom · 合并进虎码主词库")
                    .font(.callout).foregroundStyle(.secondary)
                Spacer()
                Menu {
                    Button("从鼠须管导入（合并）") { model.importPhrases(from: squirrelPhraseTable) }
                        .disabled(!FileManager.default.fileExists(atPath: squirrelPhraseTable.path))
                    Button("从文件导入…") { choosePhraseFile() }
                } label: {
                    Label("导入", systemImage: "square.and.arrow.down")
                }
                .fixedSize()
            }
            if let notice = model.phraseNotice {
                Label(notice, systemImage: "checkmark.circle").font(.callout).foregroundStyle(Theme.success)
            }
            HStack(spacing: 8) {
                TextField("词条", text: $newText).textFieldStyle(.roundedBorder).frame(minWidth: 200)
                TextField("", text: $newCode, prompt: Text("虎码编码，如 zhmn"))
                    .textFieldStyle(.roundedBorder).frame(width: 180)
                Button {
                    model.updatePhrases { $0.add(.init(text: newText, code: newCode.lowercased())) }
                    newText = ""; newCode = ""
                } label: { Label("添加", systemImage: "plus") }
                    .disabled(!CustomPhrases.Phrase(text: newText, code: newCode.lowercased()).isValid)
                Spacer()
                TextField("搜索", text: $search).textFieldStyle(.roundedBorder).frame(width: 180)
            }
            Table(filtered, selection: $selection) {
                TableColumn("词条") { phrase in Text(phrase.text) }
                TableColumn("虎码编码") { phrase in Text(phrase.code).font(.body.monospaced()) }.width(140)
                TableColumn("权重") { phrase in
                    Text(phrase.weight.map { $0 == CustomPhrases.defaultDictionaryWeight ? "默认" : String($0) } ?? "默认")
                        .foregroundStyle(.secondary)
                }.width(70)
            }
            .contextMenu(forSelectionType: CustomPhrases.Phrase.ID.self) { ids in
                Button("删除", role: .destructive) { model.updatePhrases { $0.phrases.removeAll { ids.contains($0.id) } } }
            }
            HStack {
                Text("\(model.phrases.phrases.count) 条 · \(model.store.phraseTableURL(model.phraseTable).path)")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                Spacer()
                Button("删除所选", role: .destructive) {
                    model.updatePhrases { $0.phrases.removeAll { selection.contains($0.id) } }
                    selection.removeAll()
                }
                .disabled(selection.isEmpty)
                Button("保存") { model.savePhrases() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.phrasesDirty)
                    .keyboardShortcut("s")
            }
        }
        .paneColumn()
    }
}

extension PhrasesView {
    func choosePhraseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .tabSeparatedText]
        panel.directoryURL = HufuPaths.squirrelUserDir
        panel.prompt = "导入"
        panel.message = "选择 Rime 短语表（词条<Tab>编码<Tab>权重），重复的词条会自动跳过"
        if panel.runModal() == .OK, let url = panel.url { model.importPhrases(from: url) }
    }
}

// MARK: - Sync

struct SyncView: View {
    @Environment(SettingsModel.self) private var model

    var body: some View {
        Form {
            Section { PaneHeader(title: "同步与备份", subtitle: "在多台 Mac 之间合并用户词频；或把全部配置备份成一个文件，换机、重装时一键恢复。", symbol: "arrow.triangle.2.circlepath") }

            Section("同步目录") {
                LabeledContent("位置") {
                    Text(model.syncDir ?? "默认（用户目录/sync）").foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
                HStack {
                    Button("选择文件夹…") { choose() }
                    Button("使用 iCloud Drive") {
                        let iCloud = FileManager.default.homeDirectoryForCurrentUser
                            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/Hufu/sync")
                        try? FileManager.default.createDirectory(at: iCloud, withIntermediateDirectories: true)
                        model.setSyncDir(iCloud.path)
                    }
                    Button("恢复默认") { model.setSyncDir(nil) }.disabled(model.syncDir == nil)
                }
                if let id = model.installationID {
                    LabeledContent("本机标识") { Text(id).font(.caption.monospaced()).textSelection(.enabled) }
                }
            }
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("立即同步").font(.body.weight(.medium))
                        Text("导出本机词频快照到同步目录，并合并其他设备的快照。").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("同步") { Task { await model.syncNow() } }.disabled(model.deployState == .deploying)
                }
            }
            BackupSection()
        }
        .formStyle(.cards)
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "选择"
        if panel.runModal() == .OK, let url = panel.url { model.setSyncDir(url.path) }
    }
}

/// 备份与恢复: one local file with everything the user made; restore asks first and keeps
/// a safety copy of the current state.
private struct BackupSection: View {
    @Environment(SettingsModel.self) private var model
    @State private var includeStats = false
    @State private var pending: BackupManager.Opened?

    var body: some View {
        Section {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("备份到文件").font(.body.weight(.medium))
                    Text("设置与手写配置、常用语与短语、自己的方案与词典、学到的词频。").font(.caption).foregroundStyle(.secondary)
                    Toggle("同时备份输入统计", isOn: $includeStats).toggleStyle(.checkbox).font(.caption).labeledContentStyle(.automatic)
                }
                Spacer()
                Button("备份…", action: backup).disabled(model.backupActivity != nil)
            }
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("从备份恢复").font(.body.weight(.medium))
                    Text("恢复前会先把当前配置自动备份一份，随时可以退回。").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("恢复…", action: chooseBackup).disabled(model.backupActivity != nil)
            }
            if let activity = model.backupActivity {
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text(activity).font(.caption).foregroundStyle(.secondary) }
            } else if let notice = model.backupNotice {
                Label(notice, systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(Theme.success)
            }
        } header: {
            HStack {
                Text("备份与恢复")
                Spacer()
                if FileManager.default.fileExists(atPath: model.backupManager.safetyDirectory.path) {
                    Button { NSWorkspace.shared.open(model.backupManager.safetyDirectory) } label: { Label("自动备份", systemImage: "folder") }
                        .buttonStyle(.borderless).controlSize(.small)
                        .help("恢复前自动保存的备份")
                }
            }
        } footer: {
            Text("备份只写到你选择的位置，不上传任何地方。不包含 API Key、可重新生成的编译文件和随 App 附带的词库。")
                .font(.caption).foregroundStyle(.secondary)
        }
        .sheet(item: Binding(get: { pending.map(PendingBackup.init) }, set: { if $0 == nil { pending = nil } })) { item in
            RestoreConfirmation(manifest: item.opened.manifest) {
                let opened = item.opened
                pending = nil
                Task { await model.restoreBackup(opened) }
            } cancel: {
                model.closeBackup(item.opened)
                pending = nil
            }
        }
    }

    private struct PendingBackup: Identifiable {
        let opened: BackupManager.Opened
        var id: Date { opened.manifest.created }
    }

    private func backup() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = BackupManager.suggestedName()
        if let type = UTType(filenameExtension: BackupManager.fileExtension) { panel.allowedContentTypes = [type] }
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let stats = includeStats
        Task { await model.createBackup(to: url, includeStats: stats) }
    }

    private func chooseBackup() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if let type = UTType(filenameExtension: BackupManager.fileExtension) { panel.allowedContentTypes = [type, .zip] }
        panel.prompt = "检查备份"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        pending = model.openBackup(url)
    }
}

/// What a backup holds, before anything is replaced.
private struct RestoreConfirmation: View {
    let manifest: BackupManager.Manifest
    let restore: () -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("从备份恢复", systemImage: "clock.arrow.circlepath").font(.title3.weight(.semibold))
            VStack(alignment: .leading, spacing: 8) {
                row("备份时间", manifest.created.formatted(date: .long, time: .shortened))
                if let version = manifest.appVersion { row("来自版本", version) }
                row("设置与补丁", "\(manifest.settingsCount) 个文件")
                row("短语表", "\(manifest.phraseCount) 个")
                row("词频快照", manifest.frequencyCount > 0 ? "\(manifest.frequencyCount) 个（恢复后自动合并）" : "无")
                row("输入统计", manifest.includesStats ? "\(manifest.statsCount) 个文件" : "未包含")
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text("当前的设置和短语会被替换。恢复前会自动备份当前配置，放在「自动备份」文件夹里。")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("取消", action: cancel).keyboardShortcut(.cancelAction)
                Button("恢复", action: restore).buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 440)
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.callout)
    }
}

extension View {
    /// Screenshot automation: `--scroll-to <id>` scrolls the pane to that anchor.
    func scrollTargetForScreenshots() -> some View {
        modifier(ScreenshotScroll())
    }
}

private struct ScreenshotScroll: ViewModifier {
    func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content.onAppear {
                guard let target = LaunchOptions.argument("--scroll-to") else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { proxy.scrollTo(target, anchor: .top) }
            }
        }
    }
}
