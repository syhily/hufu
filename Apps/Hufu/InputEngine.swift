import HufuCore
import HufuPanel
import AppKit
import InputMethodKit
import os
import RimeKit

/// Process-wide state of the input method: librime lifecycle, the candidate panel,
/// the resolved theme and per-app options.
@MainActor
final class InputEngine {
    static let shared = InputEngine()

    let panel = CandidatePanel()
    /// Opt-in local word statistics (高频词); off unless enabled in Settings.
    let usage = UsageRecorder()
    /// hufu/features.json, reloaded when Settings posts `HufuFeatures.changedNotification`.
    private(set) var features = HufuFeatures()
    /// 只打繁体 / 只打简体 tables (≈12k characters), read once and kept for the process.
    private(set) lazy var scriptFilter = ScriptFilter.load(sharedDataDir: paths.sharedDataDir)
    /// The user's options for the current text field: Chinese/English state, punctuation,
    /// 简繁 and Caps Lock undo. One module owns the rules; the controller applies them.
    var inputOptions = InputOptions()
    let logger = Logger(subsystem: "dev.yufan.hufu", category: "engine")
    private(set) var paths: HufuPaths
    private(set) var frontend: ConfigValue = .map([])
    private(set) var isDark = false
    /// Incremented on every (re)initialization so controllers can drop stale sessions.
    private(set) var generation = 0
    weak var activeController: HufuInputController?
    /// When the user last pressed a key. Option-change bubbles are shown only for
    /// changes the user just caused, never for ones Hufu makes itself (app options).
    var lastUserKeyAt = Date.distantPast

    private var statusHideTask: Task<Void, Never>?
    /// Deploy/import/sync ordering and request answering. The engine and panel sit behind
    /// its `DeployDriver` interface; this type supplies the process-local pieces.
    private static let coordinator: DeployCoordinator = {
        let coordinator = DeployCoordinator(driver: InputEngine.shared)
        coordinator.onReply = { InputEngine.shared.postResult($0) }
        coordinator.onProgress = { InputEngine.shared.postProgress($0) }
        return coordinator
    }()

    private var deployCoordinator: DeployCoordinator { Self.coordinator }

    private init() {
        var paths = HufuPaths.standard
        paths.sharedDataDir = Bundle.main.sharedSupportURL
        self.paths = paths
    }

    var traits: RimeTraits {
        let shared = paths.sharedDataDir ?? Bundle.main.bundleURL
        return RimeTraits(
            sharedDataDir: shared,
            userDataDir: paths.userDataDir,
            logDir: paths.logDir,
            prebuiltDataDir: shared.appendingPathComponent("build"),
            distributionVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        )
    }

    // MARK: - Lifecycle

    func start() {
        let fm = FileManager.default
        try? fm.createDirectory(at: paths.userDataDir, withIntermediateDirectories: true)
        try? fm.createDirectory(at: paths.logDir, withIntermediateDirectories: true)

        let engine = RimeEngine.shared
        engine.notificationHandler = { [weak self] in self?.handle($0) }
        // Never block startup on the lock: if a CLI deploy is running, just load what
        // is already built and skip our own maintenance pass. The first-run import runs
        // while the coordinator holds the lock and rides that startup deploy.
        let started = deployCoordinator.start { [weak self] in
            self?.importExistingRimeConfigOnFirstRun() ?? []
        }
        if !started {
            engine.initialize(traits)
            generation += 1
            followPrimarySchema()
        }
        reloadFrontend()
        observeReloadRequests()
        startUsageStats()
    }

    // MARK: - Usage statistics

    private var usageTimer: Timer?

    private func startUsageStats() {
        guard usageTimer == nil else { return }
        reloadFeatures()
        let center = DistributedNotificationCenter.default()
        center.addObserver(forName: HufuFeatures.changedNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { InputEngine.shared.reloadFeatures() }
        }
        center.addObserver(forName: UsageStatsStore.clearedNotification, object: nil, queue: .main) { _ in
            // `clear()` returns its write task; discard it so the closure stays Void
            // (Xcode 26 rejects the inferred Task return type).
            MainActor.assumeIsolated { _ = InputEngine.shared.usage.clear() }
        }
        // Buffered counts are written every 5 minutes and when the user leaves a text field.
        let timer = Timer(timeInterval: 300, repeats: true) { _ in
            MainActor.assumeIsolated { _ = InputEngine.shared.usage.flush() }
        }
        timer.tolerance = 60
        RunLoop.main.add(timer, forMode: .common)
        usageTimer = timer
        Task.detached(priority: .background) { UsageStatsStore().prune() }
    }

    private func reloadFeatures() {
        let wasMode = features.scriptMode, wasAsciiPunct = features.asciiPunct
        let wasConvenience = (features.dateTimeCandidates, features.calculatorCandidates, features.numeralsCandidates)
        features = UserSettings(paths: paths).features
        if features.scriptMode != wasMode {
            activeController?.applyScriptOption()
            activeController?.refreshPanel()
        }
        if features.asciiPunct != wasAsciiPunct {
            inputOptions.punctuationFeatureChanged(features.asciiPunct)
            activeController?.applyPunctOption()
        }
        if wasConvenience != (features.dateTimeCandidates, features.calculatorCandidates, features.numeralsCandidates) {
            // 便利功能: the panel shows the frontend's own candidates for `/time`, `=1+2`…
            activeController?.refreshPanel()
        }
        usage.isEnabled = features.usageStats
        if !features.aiPolish { activeController?.cancelPolish() }
    }

    var firstRunMarker: URL { paths.hufuDir.appendingPathComponent(".initialized") }

    /// First launch on a Mac that already uses RIME (Squirrel): import its configuration
    /// read-only so Hufu types like the user's existing setup out of the box. The
    /// snapshots ride the startup deploy; the coordinator merges them afterwards.
    private func importExistingRimeConfigOnFirstRun() -> [String] {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: firstRunMarker.path) else { return [] }
        defer {
            try? fm.createDirectory(at: paths.hufuDir, withIntermediateDirectories: true)
            fm.createFile(atPath: firstRunMarker.path, contents: Data(ISO8601DateFormatter().string(from: Date()).utf8))
        }
        let source = HufuPaths.squirrelUserDir
        // Only when the Hufu workspace is still empty and a RIME setup exists.
        let existing = (try? fm.contentsOfDirectory(atPath: paths.userDataDir.path)) ?? []
        guard fm.fileExists(atPath: source.appendingPathComponent("default.yaml").path)
                || fm.fileExists(atPath: source.appendingPathComponent("default.custom.yaml").path),
              existing.allSatisfy({ ["hufu", "build", "installation.yaml", "user.yaml", ".DS_Store"].contains($0) })
        else { return [] }
        do {
            let importer = SquirrelImporter(paths: paths, source: source)
            let report = try importer.execute(importer.plan())
            logger.info("imported existing RIME config: \(report.copied.count, privacy: .public) entries")
            return report.snapshots
        } catch {
            logger.error("first-run import failed: \(String(describing: error), privacy: .public)")
            return []
        }
    }

    private func observeReloadRequests() {
        DistributedNotificationCenter.default().addObserver(
            forName: DeployRequest.notification, object: nil, queue: .main
        ) { note in
            guard let request = DeployRequest(userInfo: note.userInfo) else { return }
            MainActor.assumeIsolated {
                // Sync runs here because this process holds the user dictionaries open;
                // a second process cannot export them (LevelDB lock).
                switch request.mode {
                case .sync: InputEngine.shared.requestSync(request: request.id)
                case .import: InputEngine.shared.deployImported(request: request.id)
                case .auto, .full: InputEngine.shared.redeploy(request: request.id, incremental: request.mode == .auto)
                }
            }
        }
    }

    /// Settings imported a RIME directory with the CLI (`--no-deploy`). The snapshots are
    /// merged here after the deploy, because this process holds the user dictionaries open.
    func deployImported(request: String?) {
        let snapshots = SquirrelImporter.Report.load(paths)?.snapshots ?? []
        deployCoordinator.enqueue(.init(request: request, mode: .import, importedSnapshots: snapshots))
    }

    /// Applies pending configuration and restarts sessions (Settings asks for this).
    /// Text being composed is committed first so nothing the user typed is lost.
    func redeploy(request: String? = nil, incremental: Bool = false) {
        logger.info("redeploy requested")
        deployCoordinator.enqueue(.init(request: request, mode: incremental ? .auto : .full))
    }

    /// Merges user dictionaries. The running input method holds the userdbs open, so the
    /// Settings app routes this request here instead of starting a second process.
    func requestSync(request: String? = nil) {
        deployCoordinator.enqueue(.init(request: request, mode: .sync))
    }

    /// The primary schema is the first of the schema list (输入方案 › 已启用). librime
    /// starts new sessions with the schema used last instead, so when the user changes
    /// the primary in Settings, switch to it and make it the remembered one. Later
    /// switches with ⌃` are the user's and stay remembered as usual.
    func followPrimarySchema() {
        guard let primary = RimeEngine.shared.schemaList().first?.id else { return }
        let key = "appliedPrimarySchema"
        guard UserDefaults.standard.string(forKey: key) != primary else { return }
        UserDefaults.standard.set(primary, forKey: key)
        RimeEngine.shared.rememberSelectedSchema(primary)
        if let session = activeController?.session, session.currentSchema != primary { _ = session.selectSchema(primary) }
        logger.info("primary schema is now \(primary, privacy: .public)")
    }

    // MARK: - Notifications from librime

    private func handle(_ notification: RimeNotification) {
        switch notification {
        case .deployStarted:
            showStatus(deployCoordinator.isSyncing ? "同步中…" : "正在应用设置…")
        case .deploySucceeded:
            reloadFrontend()
            if deployCoordinator.isSyncing {
                // A sync does not rebuild the frontend; its own result is what counts.
                showStatus("同步完成")
                deployCoordinator.engineDidFinish(success: true)
            } else {
                showStatus(deployCoordinator.frontendDeployed ? "设置已生效" : "外观配置未能生效")
                deployCoordinator.engineDidFinish(
                    success: deployCoordinator.frontendDeployed, schemasDeployed: true)
            }
        case .deployFailed:
            showStatus(deployCoordinator.isSyncing ? "同步失败" : "设置未能生效")
            deployCoordinator.engineDidFinish(success: false)
        case let .optionChanged(name, enabled):
            guard Date().timeIntervalSince(lastUserKeyAt) < 0.6,
                  ["ascii_mode", "full_shape", "simplification", "ascii_punct", "emoji_cn",
                   "chaifen", "pinyin", "extended_char"].contains(name),
                  let session = activeController?.session else { return }
            let label = session.stateLabel(option: name, state: enabled, abbreviated: false)
            if !label.isEmpty, activeController?.isComposing == false { showStatus(label) }
        case let .schemaChanged(_, name):
            if !name.isEmpty { showStatus(name) }
        default:
            break
        }
    }

    /// Result notifications echo the request id so the settings app can match them.
    /// Distributed notifications cannot authenticate the sender; they only trigger work
    /// the user could trigger anyway (a redeploy) and carry no data back into Hufu.
    private func postProgress(_ progress: DeployProgress) {
        DistributedNotificationCenter.default().postNotificationName(
            DeployProgress.notification, object: nil, userInfo: progress.userInfo, deliverImmediately: true
        )
    }

    private func postResult(_ reply: DeployReply) {
        DistributedNotificationCenter.default().postNotificationName(
            DeployReply.notification, object: nil, userInfo: reply.userInfo, deliverImmediately: true
        )
    }

    // MARK: - Theme & app options

    func reloadFrontend() {
        guard let loaded = try? ConfigValue.load(contentsOf: paths.builtConfig("hufu")) else {
            logger.error("frontend config unavailable or invalid; keeping previous configuration")
            return
        }
        frontend = loaded
        inputOptions.setAsciiScope(
            frontend.value(at: "ascii_state/scope")?.stringValue.flatMap(AsciiStateScope.init(rawValue:)) ?? .global
        )
        refreshTheme(force: true)
    }

    func refreshTheme(force: Bool = false) {
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        guard force || dark != isDark else { return }
        isDark = dark
        panel.theme = PanelTheme(frontend: frontend, dark: dark)
    }

    struct AppOptions {
        /// Configured initial state: true = English, false = Chinese, nil = shared state.
        var asciiMode: Bool?
        /// Punctuation pinned for this app: true = English, nil = the shared state.
        var asciiPunct: Bool?
        var inline: Bool?
        var vimMode = false
    }

    func appOptions(for bundleID: String?) -> AppOptions {
        guard let bundleID, let options = frontend["app_options"]?[bundleID] else { return AppOptions() }
        var result = AppOptions()
        result.asciiMode = options["ascii_mode"]?.boolValue
        result.asciiPunct = options["ascii_punct"]?.boolValue
        if options["no_inline"]?.boolValue == true { result.inline = false }
        if options["inline"]?.boolValue == true { result.inline = true }
        result.vimMode = options["vim_mode"]?.boolValue ?? false
        return result
    }

    // MARK: - Status bubble

    func showStatus(_ text: String) {
        statusHideTask?.cancel()
        panel.show(PanelState(status: text), at: activeController?.cursorRect() ?? .zero)
        statusHideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled, let self else { return }
            if let controller = self.activeController { controller.restorePanelAfterStatus() } else { self.panel.hide() }
        }
    }

    func cancelStatus() { statusHideTask?.cancel() }

    private var deployNoticeGeneration = -1

    /// Shows "正在应用设置…" at most once per engine generation when keys arrive mid-apply.
    func noteKeyDuringDeploy() {
        guard deployNoticeGeneration != generation else { return }
        deployNoticeGeneration = generation
        showStatus("正在应用设置，稍候即可输入中文…")
    }
}

// MARK: - DeployDriver

extension InputEngine: DeployDriver {
    func acquireLock() -> (any DeployLock)? { WorkspaceLock.acquire(paths) }

    func prepareForDeploy() throws -> [String] {
        do {
            return try ConfigLayers(paths: paths).prepareForDeploy(
                extraTargets: ConfigLayers.shippedTargets(sharedDataDir: paths.sharedDataDir)
            )
        } catch {
            logger.error("config layers invalid, keeping previous build: \(String(describing: error), privacy: .public)")
            throw error
        }
    }

    func prepareForRestart() {
        activeController?.cancelPolish()
        activeController?.flushBeforeEngineRestart()
        panel.hide()
    }

    func restartEngine() {
        let engine = RimeEngine.shared
        engine.cleanupAllSessions()
        engine.initialize(traits)
        generation += 1
    }

    func deployFrontend() -> Bool {
        let ok = RimeEngine.shared.deployConfigFile("hufu.yaml")
        reloadFrontend()
        return ok
    }

    func startMaintenance(fullCheck: Bool) -> Bool {
        RimeEngine.shared.startMaintenance(fullCheck: fullCheck)
    }

    func markDeployed() { ConfigLayers(paths: paths).markDeployed() }

    func prepareForSync() {
        activeController?.flushBeforeEngineRestart()
        RimeEngine.shared.cleanupAllSessions()
        generation += 1
    }

    func joinMaintenance() { RimeEngine.shared.joinMaintenance() }

    func restoreUserDictionary(named name: String) -> Bool {
        RimeEngine.shared.restoreUserDictionary(from: paths.userDataDir.appendingPathComponent("sync/\(name)"))
    }

    func syncUserData() -> Bool { RimeEngine.shared.syncUserData() }

    func recordImportWarning(_ message: String) {
        SquirrelImporter.Report.appendWarning(message, paths: paths)
    }

    func missingSchemas() -> [String] {
        DeployVerification.missingSchemas(stagingDir: paths.stagingDir)
    }

    var logDirectory: URL { paths.logDir }
}
