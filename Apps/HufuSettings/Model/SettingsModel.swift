import HufuAI
import HufuCore
import HufuPanel
import AppKit
import Carbon
import Observation

/// Single source of state for the settings window. Reads deployed values through
/// `SettingsStore`, writes into the generated layer, and asks the input method (or the
/// bundled CLI) to deploy.
@MainActor
@Observable
final class SettingsModel {
    enum DeployState: Equatable {
        case idle
        case deploying
        case succeeded(Date)
        case failed(String)
    }

    let paths: HufuPaths
    let store: SettingsStore
    let catalog: SettingCatalog
    let deployer: DeployService

    /// Bumped after every write so views re-read values.
    private(set) var revision = 0
    /// Any write marks changes pending; they are applied automatically shortly after.
    private(set) var hasPendingChanges = false {
        didSet { if hasPendingChanges { changeCount += 1; scheduleAutoDeploy() } }
    }
    private(set) var deployState: DeployState = .idle
    private var changeCount = 0
    private var autoDeployTask: Task<Void, Never>?
    private(set) var lastError: String?

    var phrases: CustomPhrases
    private(set) var phrasesDirty = false
    /// The user table merged into tigress through `import_tables`.
    private(set) var phraseTable = PhraseTable.hufu
    private(set) var phraseNotice: String?

    init() {
        var paths = HufuPaths.standard
        paths.sharedDataDir = Locations.sharedSupport
        self.paths = paths
        self.store = SettingsStore(paths: paths)
        self.catalog = store.catalog
        self.deployer = DeployService(paths: paths)
        self.phrases = CustomPhrases.loadDictionary(from: store.phraseTableURL(.hufu))
        hasPendingChanges = !ConfigLayers(paths: paths).dirtyTargets().isEmpty
        // Changes left from a previous session are applied right away.
        if hasPendingChanges { scheduleAutoDeploy() }
        // The shipped schema mounts words_simp; the product default is off, and a crash
        // between "switch flipped" and "deploy done" must not leave the mount behind.
        syncWordTables()
    }

    // MARK: - Status

    var isInstalled: Bool { Locations.inputMethodApp != nil }

    enum InputSourceState {
        /// Not known to Text Input Sources at all.
        case missing
        /// Registered but not added in System Settings › Keyboard › Input Sources.
        case notAdded
        /// The mode reports enabled but its input method is not: right after a first install
        /// (or a move between /Library and ~/Library) macOS lists and selects Hufu only after
        /// the user logs out and back in (#8).
        case needsRelogin
        case ready
    }

    var inputSourceState: InputSourceState {
        _ = revision
        func enabled(_ id: String) -> Bool? {
            let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
            guard let list = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource],
                  let source = list.first else { return nil }
            guard let raw = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsEnabled) else { return false }
            return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(raw).takeUnretainedValue())
        }
        guard let mode = enabled("dev.yufan.hufu.inputmethod.hans") else { return .missing }
        guard mode else { return .notAdded }
        return enabled("dev.yufan.hufu.inputmethod") == false ? .needsRelogin : .ready
    }

    /// Whether Hufu can be switched to right now.
    var isInputSourceEnabled: Bool { inputSourceState == .ready }
    var isDeployed: Bool { FileManager.default.fileExists(atPath: paths.builtConfig("default").path) }
    var enabledSchemas: [String] { _ = revision; return store.pendingSchemas() }
    var squirrelDirExists: Bool { FileManager.default.fileExists(atPath: HufuPaths.squirrelUserDir.path) }
    var importReport: URL { paths.hufuDir.appendingPathComponent("import-report.json") }
    var hasImported: Bool { FileManager.default.fileExists(atPath: importReport.path) }
    /// What the last import could not carry over (e.g. learned frequencies). A successful
    /// deploy says nothing about these, so the import card shows them (#23).
    var importWarnings: [String] { _ = revision; return SquirrelImporter.Report.load(paths)?.warnings ?? [] }

    // MARK: - Settings

    func value(_ setting: SettingCatalog.Setting) -> ConfigValue? {
        _ = revision
        return store.value(for: setting)
    }

    func isCustomized(_ setting: SettingCatalog.Setting) -> Bool {
        _ = revision
        return store.isCustomized(setting)
    }

    func set(_ value: ConfigValue, for setting: SettingCatalog.Setting) {
        perform { try store.set(value, for: setting) }
    }

    func reset(_ setting: SettingCatalog.Setting) {
        perform { try store.reset(setting) }
    }

    func setting(_ id: String) -> SettingCatalog.Setting? { catalog.setting(id) }

    /// Switch options of the primary schema, for multi-select controls.
    var availableSwitches: [(name: String, title: String)] {
        _ = revision
        guard let schema = enabledSchemas.first,
              let switches = store.built(.schema(schema))?.value(at: "switches")?.listValue else { return [] }
        let known = ["ascii_mode": "中英文", "full_shape": "全角", "ascii_punct": "英文标点",
                     "simplification": "繁体", "emoji_cn": "Emoji", "chaifen": "拆分",
                     "pinyin": "拼音注解", "extended_char": "常用字"]
        return switches.compactMap { item -> (String, String)? in
            guard let name = item["name"]?.stringValue else { return nil }
            let states = item["states"]?.listValue?.compactMap(\.stringValue) ?? []
            return (name, known[name] ?? (states.last ?? name))
        }
    }

    var appOptions: [SettingsStore.AppOption] { _ = revision; return store.appOptions() }

    func setAppOption(_ option: SettingsStore.AppOption) { perform { try store.setAppOption(option) } }
    func removeAppOption(_ bundleID: String) { perform { try store.removeAppOption(bundleID) } }

    // MARK: - 智能配置 (recommended per-app options)

    enum AppScanPhase: Equatable {
        case idle
        case scanning(fraction: Double, name: String, path: String?)
        case review
        case applied(Int)
    }

    private(set) var appScanPhase: AppScanPhase = .idle
    private(set) var appSuggestions: [AppRecommendations.Suggestion] = []

    /// Scans installed apps and proposes options from the recommendation rules; nothing
    /// is written until `applyAppSuggestions()`.
    func scanInstalledApps() async {
        guard appScanPhase == .idle || appScanPhase == .review || { if case .applied = appScanPhase { true } else { false } }() else { return }
        appSuggestions = []
        appScanPhase = .scanning(fraction: 0, name: "", path: nil)
        let apps = await AppScanner.scan { [weak self] fraction, app in
            self?.appScanPhase = .scanning(fraction: fraction, name: app.name, path: app.url?.path)
        }
        let existing = Set(store.appOptions().map(\.bundleID))
        appSuggestions = AppRecommendations.load(paths).suggestions(for: apps, existing: existing)
        appScanPhase = .review
    }

    /// Apps that already have options (shown as "kept" in onboarding).
    var configuredAppCount: Int { _ = revision; return store.appOptions().count }

    func toggleAppSuggestion(_ id: String) {
        guard let index = appSuggestions.firstIndex(where: { $0.id == id }) else { return }
        appSuggestions[index].selected.toggle()
    }

    /// Changing the mode of a row also ticks it: the user evidently wants it applied.
    func setAppSuggestionMode(_ id: String, _ mode: SettingsStore.AppOption.InitialMode) {
        guard let index = appSuggestions.firstIndex(where: { $0.id == id }) else { return }
        appSuggestions[index].initialMode = mode
        appSuggestions[index].selected = true
    }

    func applyAppSuggestions() {
        let chosen = appSuggestions.filter(\.selected)
        perform { for suggestion in chosen { try store.setAppOption(suggestion.option) } }
        appSuggestions = []
        appScanPhase = .applied(chosen.count)
    }

    func dismissAppScan() {
        appSuggestions = []
        appScanPhase = .idle
    }

    /// Runs a write, records pending state and refreshes views.
    func perform(_ body: () throws -> Void) {
        do {
            try body()
            hasPendingChanges = true
            lastError = nil
        } catch {
            lastError = String(describing: error)
        }
        revision += 1
    }

    // MARK: - Appearance

    var previewFrontend: ConfigValue { _ = revision; return store.previewFrontend() }

    func theme(dark: Bool, scheme: String? = nil) -> PanelTheme {
        PanelTheme(frontend: previewFrontend, dark: dark, schemeOverride: scheme)
    }

    var colorSchemes: [(id: String, name: String)] { PanelTheme.schemeNames(in: previewFrontend) }

    static let customSchemeID = "hufu_custom"

    /// Copies a scheme into the editable `hufu_custom` scheme and selects it.
    func customizeScheme(from base: PanelTheme) {
        let colors: [(String, ThemeColor)] = [
            ("back_color", base.backColor), ("border_color", base.borderColor),
            ("preedit_back_color", base.preeditBackColor), ("text_color", base.textColor),
            ("hilited_text_color", base.hilitedTextColor), ("hilited_back_color", base.hilitedBackColor),
            ("candidate_text_color", base.candidateTextColor), ("comment_text_color", base.commentTextColor),
            ("label_color", base.labelColor), ("hilited_candidate_back_color", base.hilitedCandidateBackColor),
            ("hilited_candidate_text_color", base.hilitedCandidateTextColor),
            ("hilited_comment_text_color", base.hilitedCommentTextColor),
            ("hilited_candidate_label_color", base.hilitedCandidateLabelColor),
        ]
        let scheme = ConfigValue.map(
            [.init("name", "我的配色"), .init("author", "Hufu Settings"), .init("color_format", "argb")]
                + colors.map { .init($0.0, .string($0.1.argbString)) }
        )
        perform {
            try store.layers.updateGenerated(.frontend) { patch in
                patch.removeAll { $0.key.hasPrefix("preset_color_schemes/\(Self.customSchemeID)") }
                patch.append(.init("preset_color_schemes/\(Self.customSchemeID)", scheme))
                patch.removeAll { $0.key == "style/color_scheme" || $0.key == "style/color_scheme_dark" }
                patch.append(.init("style/color_scheme", .string(Self.customSchemeID)))
                patch.append(.init("style/color_scheme_dark", .string(Self.customSchemeID)))
            }
        }
    }

    // MARK: - Theme links (hufu-ime://theme, docs/themes.md)

    /// Links waiting for confirmation, shown one at a time.
    private(set) var themeImports: [ThemePackage.Decoded] = []
    private(set) var themeImportError: String?
    private(set) var themeNotice: String?

    /// Validates an `hufu-ime://theme` link and queues it; nothing is written until the
    /// user confirms in the import sheet.
    func receiveThemeLink(_ url: URL) {
        do {
            let decoded = try ThemePackage.decode(url: url)
            guard !themeImports.contains(where: { $0.package == decoded.package }) else { return }
            themeImports.append(decoded)
            themeImportError = nil
        } catch {
            themeImportError = error.localizedDescription
        }
    }

    func themeImportPlan(_ package: ThemePackage) -> ThemeImportPlan {
        ThemeImportPlan(package: package, frontend: previewFrontend,
                        generatedPatch: (try? store.layers.generatedPatch(.frontend)) ?? [])
    }

    /// How a package would render with the user's own layout and font.
    /// With `adoptLayout`, the theme's radii, padding and font sizes replace the user's
    /// own panel settings, as they would after importing.
    func theme(for package: ThemePackage, dark: Bool, adoptLayout: Bool = false) -> PanelTheme {
        var frontend = previewFrontend
        frontend.set(package.schemeValue, at: "preset_color_schemes/\(package.id)")
        if adoptLayout, let layout = package.layout {
            for (key, value) in layout { frontend.set(.double(value), at: "style/hufu/\(key)") }
        }
        return PanelTheme(frontend: frontend, dark: dark, schemeOverride: package.id)
    }

    func confirmThemeImport(activate: Bool, target: ThemeImportPlan.Target, adoptLayout: Bool = false) {
        guard let decoded = themeImports.first else { return }
        let plan = themeImportPlan(decoded.package)
        perform {
            try store.layers.updateGenerated(.frontend) { patch in
                plan.apply(to: &patch, activate: activate, target: target, adoptLayout: adoptLayout)
            }
        }
        themeNotice = plan.isBuiltIn ? "已切换到内置主题「\(decoded.package.name)」"
            : activate ? "已导入并启用「\(decoded.package.name)」" : "已导入「\(decoded.package.name)」，可在外观中选择"
        themeImports.removeFirst()
    }

    func cancelThemeImport() {
        if !themeImports.isEmpty { themeImports.removeFirst() }
    }

    func dismissThemeImportError() { themeImportError = nil }
    func dismissThemeNotice() { themeNotice = nil }

    // MARK: - Deploy

    /// Coalesces bursts of edits (slider drags, several toggles) into one deploy.
    private func scheduleAutoDeploy() {
        autoDeployTask?.cancel()
        autoDeployTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled, let self else { return }
            await self.deploy()
        }
    }

    /// Applies pending changes. There is no user-facing deploy: every write ends up here,
    /// and incremental vs full is decided per change (appearance reloads in milliseconds;
    /// schema and phrase edits rebuild, see `needsEngineReload`). One automatic retry
    /// covers a transient failure; past that the banner stays up and the next change
    /// tries again.
    private func deploy(retries: Int = 1) async {
        // Deploys run one after another; a request made meanwhile waits for its turn.
        let previous = deployChain
        let task = Task { [weak self] in
            await previous?.value
            await self?.performDeploy()
        }
        deployChain = task
        await task.value
        guard case .failed = deployState, retries > 0, hasPendingChanges else { return }
        try? await Task.sleep(for: .seconds(2))
        guard hasPendingChanges else { return }
        await deploy(retries: retries - 1)
    }

    private var deployChain: Task<Void, Never>?
    /// Phrase tables are read when librime builds a session: after editing them, the
    /// appearance-only fast path is not enough and the sessions must be recreated.
    @ObservationIgnored private var needsEngineReload = false

    private func performDeploy() async {
        // A pass queued behind another may find nothing left to apply.
        guard hasPendingChanges else { return }
        let startedWith = changeCount
        deployState = .deploying
        let reload = needsEngineReload
        needsEngineReload = false
        let result = await deployer.deploy(automatic: !reload)
        switch result {
        case .success:
            deployState = .succeeded(Date())
            if changeCount == startedWith { hasPendingChanges = false }
            lastError = nil
        case let .failure(message):
            deployState = .failed(message)
            lastError = "设置未能生效：\(message)"
            if reload { needsEngineReload = true }
        }
        revision += 1
        // Edits made while deploying get their own pass.
        if changeCount != startedWith, case .succeeded = deployState { scheduleAutoDeploy() }
    }

    /// Merges phrases from a table file into huma_custom (duplicates skipped).
    func importPhrases(from url: URL) {
        if phrasesDirty { savePhrases() }
        do {
            let result = try store.importPhrases(from: url, into: phraseTable)
            phrases = CustomPhrases.loadDictionary(from: store.phraseTableURL(phraseTable))
            phraseNotice = "已导入 \(result.added) 条，跳过 \(result.skipped) 条重复或无效"
            if result.added > 0 { needsEngineReload = true; hasPendingChanges = true }
        } catch {
            lastError = String(describing: error)
        }
        revision += 1
    }

    /// Plan of a RIME directory import (dry run), shown before importing.
    func importPlan(from source: URL) -> [SquirrelImporter.Action] {
        (try? SquirrelImporter(paths: paths, source: source).plan().actions) ?? []
    }

    func importSquirrel(from source: URL = HufuPaths.squirrelUserDir) async {
        deployState = .deploying
        if deployer.usesInputMethod {
            // The running input method holds the user dictionaries: import here, then let it
            // deploy and merge the learned-frequency snapshots (#23).
            let result = await deployer.run(["import-squirrel", "--from", source.path, "--no-deploy"])
            if result.ok {
                switch await deployer.deployImportedViaInputMethod() {
                case .success: deployState = .succeeded(Date())
                case let .failure(message): deployState = .failed(message)
                }
            } else {
                deployState = .failed(result.output.suffix(400).description)
            }
        } else {
            let result = await deployer.run(["import-squirrel", "--from", source.path])
            deployState = result.ok ? .succeeded(Date()) : .failed(result.output.suffix(400).description)
        }
        phrases = CustomPhrases.loadDictionary(from: store.phraseTableURL(phraseTable))
        if case .succeeded = deployState { hasPendingChanges = false }
        revision += 1
    }

    // MARK: - Phrases

    func updatePhrases(_ body: (inout CustomPhrases) -> Void) {
        body(&phrases)
        phrasesDirty = true
    }

    func savePhrases() {
        do {
            try phrases.saveDictionary(to: store.phraseTableURL(phraseTable))
            phrasesDirty = false
            needsEngineReload = true
            hasPendingChanges = true
        } catch {
            lastError = String(describing: error)
        }
    }

    var baseDictionaryMetadata: DictionaryMetadata? { DictionaryMetadata.load(paths) }

    // MARK: - 常用语 (snippets)

    var snippets: Snippets { _ = revision; return Snippets.load(paths) }

    /// Saves right away; the input method reads the file when the quick menu opens, so
    /// no deploy is needed.
    func updateSnippets(_ body: (inout Snippets) -> Void) {
        var value = Snippets.load(paths)
        body(&value)
        do { try value.save(paths) } catch { lastError = String(describing: error) }
        revision += 1
    }

    // MARK: - Usage statistics

    let statsStore = UsageStatsStore()
    var features: HufuFeatures { _ = revision; return HufuFeatures.load(paths) }

    func setUsageStats(_ enabled: Bool) { updateFeatures { $0.usageStats = enabled } }

    /// Writes hufu/features.json and tells the input method to reload it.
    func updateFeatures(_ body: (inout HufuFeatures) -> Void) {
        var features = HufuFeatures.load(paths)
        let before = features
        body(&features)
        // Consent to send text is given for one host; a new endpoint needs it again.
        if URL(string: features.aiBaseURL)?.host() != URL(string: before.aiBaseURL)?.host() { features.aiRemoteAllowed = false }
        guard features != before else { return }
        do {
            try features.save(paths)
            DistributedNotificationCenter.default().postNotificationName(
                HufuFeatures.changedNotification, object: nil, userInfo: nil, deliverImmediately: true)
        } catch {
            lastError = String(describing: error)
        }
        revision += 1
        // 词汇输入 sits in the schema, not in features.json: rewrite the mount and let the
        // ordinary auto-deploy apply it (no separate confirmation).
        if features.wordsEnabled != before.wordsEnabled || features.scriptMode != before.scriptMode {
            syncWordTables()
        }
    }

    /// Writes the word-table mount derived from the current features. Silent when it
    /// already matches; otherwise the pending flag schedules the usual deploy.
    private func syncWordTables() {
        let features = self.features
        do {
            if try store.applyWordTables(enabled: features.wordsEnabled, mode: features.scriptMode) {
                hasPendingChanges = true
            }
        } catch {
            lastError = String(describing: error)
        }
        revision += 1
    }

    func usageSummary(days: Int) -> UsageSummary { _ = revision; _ = statsRevision; return statsStore.summary(days: days) }

    /// Bumped to re-read the statistics files (the input method writes them every few minutes).
    private(set) var statsRevision = 0
    @ObservationIgnored private var cachedReport: (revision: Int, report: ActivityReport)?

    func refreshStats() { statsRevision += 1 }

    /// 输入统计: totals, series and breakdowns, read once per refresh.
    func activityReport() -> ActivityReport {
        let key = revision &* 1_000_003 &+ statsRevision
        if let cachedReport, cachedReport.revision == key { return cachedReport.report }
        let report = statsStore.report()
        cachedReport = (key, report)
        return report
    }

    func clearUsageStats() {
        statsStore.clear()
        DistributedNotificationCenter.default().postNotificationName(
            UsageStatsStore.clearedNotification, object: nil, userInfo: nil, deliverImmediately: true)
        revision += 1
    }

    func blockUsageWord(_ word: String) {
        do { try statsStore.block(word) } catch { lastError = String(describing: error) }
        revision += 1
    }

    /// Pins a word to the top of its 虎码 code's candidates. The code is entered by hand:
    /// hufu has no local pinyin-to-code conversion.
    func pinUsageWord(_ word: String, code: String) -> Bool {
        let code = code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !code.isEmpty else { return false }
        updatePhrases { _ = $0.add(.init(text: word, code: code, weight: 99_999_999)) }
        savePhrases()
        revision += 1
        return true
    }

    func isPinned(_ word: String) -> Bool { phrases.phrases.contains { $0.text == word } }

    /// Removes every entry for the word; returns false when it was written by hand and
    /// is not in the table.
    func unpinUsageWord(_ word: String) -> Bool {
        let before = phrases.phrases.count
        updatePhrases { $0.phrases.removeAll { $0.text == word } }
        guard phrases.phrases.count != before else { return false }
        savePhrases()
        revision += 1
        return true
    }

    // MARK: - Sync

    var syncDir: String? { _ = revision; return store.syncDir }
    var installationID: String? { _ = revision; return store.installationInfo()["installation_id"]?.stringValue }

    func setSyncDir(_ path: String?) { perform { try store.setSyncDir(path) } }

    @discardableResult
    func syncNow() async -> Bool {
        deployState = .deploying
        let outcome = await deployer.sync()
        switch outcome {
        case .success: deployState = .succeeded(Date())
        case let .failure(message): deployState = .failed(message)
        }
        revision += 1
        return outcome == .success
    }

    // MARK: - Backup (local only)

    private(set) var backupActivity: String?
    private(set) var backupNotice: String?
    var backupManager: BackupManager { BackupManager(paths: paths, statsDirectory: statsStore.directory) }

    /// Exports fresh frequency snapshots (RIME sync), then writes the backup file.
    func createBackup(to url: URL, includeStats: Bool) async {
        backupActivity = "正在导出词频快照…"
        let synced = await syncNow()
        backupActivity = "正在打包…"
        defer { backupActivity = nil }
        let manager = backupManager
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        do {
            let manifest = try await Task.detached { try manager.create(at: url, includeStats: includeStats, appVersion: version) }.value
            backupNotice = synced
                ? "已备份 \(manifest.files.count) 个文件到 \(url.lastPathComponent)"
                : "已备份 \(manifest.files.count) 个文件到 \(url.lastPathComponent)，但词频同步失败，备份未包含最新词频"
        } catch {
            lastError = "备份失败：\(error)"
        }
    }

    /// Unpacks and verifies a backup; nothing changes until `restoreBackup`.
    func openBackup(_ url: URL) -> BackupManager.Opened? {
        do { return try backupManager.open(url) } catch {
            lastError = "无法读取备份：\(error)"
            return nil
        }
    }

    /// Restores, then rebuilds everything: features reload in the input method, layers
    /// and phrase tables deploy, frequency snapshots merge through RIME sync.
    func restoreBackup(_ opened: BackupManager.Opened) async {
        backupActivity = "正在恢复…"
        defer { backupActivity = nil }
        do {
            let safety = try backupManager.restore(opened)
            backupNotice = "已恢复。恢复前的配置已自动备份为「\(safety.lastPathComponent)」"
        } catch {
            lastError = "恢复失败：\(error)"
            return
        }
        DistributedNotificationCenter.default().postNotificationName(
            HufuFeatures.changedNotification, object: nil, userInfo: nil, deliverImmediately: true)
        phraseTable = .hufu
        phrases = CustomPhrases.loadDictionary(from: store.phraseTableURL(.hufu))
        needsEngineReload = true
        hasPendingChanges = true
        revision += 1
        await deploy()
        await syncNow()
    }

    func closeBackup(_ opened: BackupManager.Opened) { backupManager.close(opened) }

    func dismissError() { lastError = nil }

    // MARK: - Version

    let currentVersion = AppVersion.current()
    /// Ad-hoc development builds (install-dev.sh) are shown as such.
    let isDistributionBuild = AppVersion.isDistributionBuild()
}
