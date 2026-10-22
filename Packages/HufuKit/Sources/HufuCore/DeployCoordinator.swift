public import Foundation

/// A held workspace lock. The coordinator only needs to keep it alive; releasing is the
/// lock's own deinit.
public protocol DeployLock: AnyObject {}

extension WorkspaceLock: DeployLock {}

/// What the coordinator needs from the process that owns librime and the candidate UI.
/// InputEngine implements this; tests use a fake.
@MainActor
public protocol DeployDriver: AnyObject {
    func acquireLock() -> (any DeployLock)?
    /// Composes the patch layers and drops dirty build output.
    func prepareForDeploy() throws -> [String]
    /// Cancels AI work, commits the composition and hides the panel before sessions die.
    func prepareForRestart()
    /// Cleans sessions, re-initializes librime and invalidates the session generation.
    func restartEngine()
    func deployFrontend() -> Bool
    func startMaintenance(fullCheck: Bool) -> Bool
    func markDeployed()
    func followPrimarySchema()
    /// Commits the composition and closes sessions before a user-dictionary sync.
    func prepareForSync()
    func joinMaintenance()
    func restoreUserDictionary(named name: String) -> Bool
    func syncUserData() -> Bool
    func recordImportWarning(_ message: String)
    /// Built schema configs missing from the staging directory.
    func missingSchemas() -> [String]
    var logDirectory: URL { get }
}

/// Owns deploy/import/sync ordering: one queue, one workspace lock, one acknowledgement,
/// one place that answers requests. The engine and UI sit behind `DeployDriver`.
@MainActor
public final class DeployCoordinator {
    public struct Job: Sendable, Equatable {
        public var request: String?
        public var mode: DeployMode
        public var importedSnapshots: [String]

        public init(request: String? = nil, mode: DeployMode, importedSnapshots: [String] = []) {
            self.request = request
            self.mode = mode
            self.importedSnapshots = importedSnapshots
        }
    }

    public var onReply: ((DeployReply) -> Void)?
    public var onProgress: ((DeployProgress) -> Void)?

    public private(set) var isSyncing = false
    public private(set) var isDeploying = false
    public private(set) var frontendDeployed = true
    public var isBusy: Bool { deployLock != nil }
    public var hasQueuedWork: Bool { !queue.isEmpty }

    private let driver: any DeployDriver
    private let retryDelay: Duration
    private let timeout: Duration

    private var queue: [Job] = []
    private var deployLock: (any DeployLock)?
    private var pendingRequests: [String?] = []
    private var awaitingDeployAck = false
    private var runningImport: ImportJob?
    private var lockRetryTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?

    private struct ImportJob {
        var requests: [String?]
        var snapshots: [String]
    }

    public init(
        driver: any DeployDriver,
        retryDelay: Duration = .milliseconds(300),
        timeout: Duration = DeployProtocol.timeout
    ) {
        self.driver = driver
        self.retryDelay = retryDelay
        self.timeout = timeout
    }

    /// Takes the workspace lock and runs the startup deploy. `beforePrepare` runs while
    /// the lock is held (the first-run import); it returns the snapshots to merge after
    /// the deploy. Returns false when another process holds the lock.
    @discardableResult
    public func start(beforePrepare: (() -> [String])? = nil) -> Bool {
        guard deployLock == nil, let lock = driver.acquireLock() else { return false }
        let snapshots = beforePrepare?() ?? []
        let dirty = try? driver.prepareForDeploy()
        if !snapshots.isEmpty { runningImport = ImportJob(requests: [], snapshots: snapshots) }
        deployLock = lock
        awaitingDeployAck = dirty != nil
        isDeploying = true
        driver.restartEngine()
        frontendDeployed = driver.deployFrontend()
        if !driver.startMaintenance(fullCheck: dirty?.isEmpty == false) {
            if dirty?.isEmpty == true { driver.markDeployed() }
            awaitingDeployAck = false
            isDeploying = false
            deployLock = nil
            finishImport(deployed: true)
            drain()
        } else {
            armTimeout()
        }
        return true
    }

    /// Queues a deploy/import. Sync is answered immediately: the input method holds the
    /// userdbs open, so a sync cannot wait behind its own deploy without deadlocking the
    /// settings UI.
    public func enqueue(_ job: Job) {
        if job.mode == .sync {
            guard deployLock == nil, let lock = driver.acquireLock() else {
                reply(request: job.request, ok: false, message: "另一个操作正在进行，请稍后再同步")
                return
            }
            runSync(requests: [job.request], importedSnapshots: job.importedSnapshots, lock: lock)
            return
        }
        queue.append(job)
        drain()
    }

    /// Called from the librime notification handler once a deploy or sync ends.
    public func engineDidFinish(success: Bool, schemasDeployed: Bool? = nil) {
        timeoutTask?.cancel()
        timeoutTask = nil
        let wasSyncing = isSyncing
        var ok = success
        var message: String? = ok ? nil : (wasSyncing ? "同步失败，详见日志" : "应用失败，详见日志")
        if ok, !wasSyncing {
            let missing = driver.missingSchemas()
            if !missing.isEmpty {
                ok = false
                message = "方案编译不完整：\(missing.joined(separator: "、"))"
            }
        }
        if ok, awaitingDeployAck { driver.markDeployed() }
        awaitingDeployAck = false
        if ok { driver.followPrimarySchema() }
        isSyncing = false
        isDeploying = false
        deployLock = nil
        let requests = pendingRequests
        pendingRequests = []
        for request in requests { reply(request: request, ok: ok, message: message) }
        finishImport(deployed: schemasDeployed ?? ok, message: message)
        drain()
    }

    // MARK: - Queue

    private func drain(attempt: Int = 0) {
        guard deployLock == nil, !queue.isEmpty else { return }
        guard let lock = driver.acquireLock() else {
            guard attempt < 50 else {
                let batch = queue
                queue.removeAll()
                // Imports get their own answer (and warning) from failImport.
                for job in batch where job.mode != .import {
                    reply(request: job.request, ok: false, message: "工作区被其他进程占用")
                }
                if let job = Self.importJob(batch) { failImport(job, message: "工作区被其他进程占用，词频快照未合并") }
                return
            }
            lockRetryTask?.cancel()
            lockRetryTask = Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(for: self.retryDelay)
                self.drain(attempt: attempt + 1)
            }
            return
        }
        let batch = queue
        queue.removeAll()
        let job = Self.importJob(batch)
        runningImport = job
        runDeploy(
            requests: batch.filter { $0.mode != .import }.map(\.request),
            incremental: job == nil && batch.allSatisfy { $0.mode == .auto },
            lock: lock
        )
    }

    private static func importJob(_ batch: [Job]) -> ImportJob? {
        let imports = batch.filter { $0.mode == .import }
        guard !imports.isEmpty else { return nil }
        var snapshots: [String] = []
        for name in imports.flatMap(\.importedSnapshots) where !snapshots.contains(name) {
            snapshots.append(name)
        }
        return ImportJob(requests: imports.map(\.request), snapshots: snapshots)
    }

    private func runDeploy(requests: [String?], incremental: Bool, lock: any DeployLock) {
        let dirty: [String]
        do {
            dirty = try driver.prepareForDeploy()
        } catch {
            let message = String(describing: error)
            for request in requests { reply(request: request, ok: false, message: message) }
            if let job = runningImport {
                runningImport = nil
                failImport(job, message: message)
            }
            drain()
            return
        }

        if incremental, dirty.allSatisfy({ $0 == "hufu" }) {
            for request in requests { onProgress?(DeployProgress(request: request, stage: "frontend", total: 0)) }
            let ok = dirty.isEmpty || driver.deployFrontend()
            if ok {
                frontendDeployed = true
                driver.markDeployed()
            }
            for request in requests {
                reply(request: request, ok: ok, message: ok ? nil : "外观配置编译失败，详见日志")
            }
            withExtendedLifetime(lock) {}
            drain()
            return
        }

        let schemaCount = dirty.filter { $0 != "hufu" }.count
        for request in requests {
            onProgress?(DeployProgress(request: request, stage: "schemas", total: schemaCount))
        }
        deployLock = lock
        awaitingDeployAck = true
        pendingRequests = requests
        isDeploying = true
        armTimeout()
        driver.prepareForRestart()
        driver.restartEngine()
        frontendDeployed = driver.deployFrontend()
        if !driver.startMaintenance(fullCheck: true) {
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.engineDidFinish(success: self.frontendDeployed, schemasDeployed: true)
            }
        }
    }

    // MARK: - Sync

    private func runSync(requests: [String?], importedSnapshots: [String], lock: any DeployLock) {
        deployLock = lock
        isSyncing = true
        pendingRequests = requests
        armTimeout()
        driver.prepareForSync()
        if !importedSnapshots.isEmpty {
            driver.joinMaintenance()
            let restorable = importedSnapshots.prefix(256)
            let failed = restorable.filter { !driver.restoreUserDictionary(named: $0) }.count
                + importedSnapshots.count - restorable.count
            if failed > 0 {
                driver.recordImportWarning(SquirrelImporter.Report.mergeFailed(failed))
            }
        }
        if !driver.syncUserData() {
            if !importedSnapshots.isEmpty {
                driver.recordImportWarning(SquirrelImporter.Report.mergeFailed(importedSnapshots.count))
            }
            deployLock = nil
            isSyncing = false
            for request in requests { reply(request: request, ok: false, message: "同步未能开始，详见日志") }
            pendingRequests = []
            timeoutTask?.cancel()
            timeoutTask = nil
            drain()
        }
    }

    // MARK: - Import ride

    private func finishImport(deployed: Bool, message: String? = nil) {
        guard let job = runningImport else { return }
        runningImport = nil
        guard deployed else {
            failImport(job, message: message ?? "应用失败，词频快照未合并，详见日志")
            return
        }
        guard !job.snapshots.isEmpty else {
            for request in job.requests { reply(request: request, ok: true, message: nil) }
            return
        }
        guard let lock = driver.acquireLock() else {
            failImport(job, message: "工作区被其他进程占用，词频快照未合并")
            return
        }
        let frontendFailed = !frontendDeployed
        if frontendFailed {
            runSync(requests: [], importedSnapshots: job.snapshots, lock: lock)
            for request in job.requests {
                reply(request: request, ok: false, message: "配置已导入，但外观配置编译失败，详见日志")
            }
        } else {
            runSync(requests: job.requests, importedSnapshots: job.snapshots, lock: lock)
        }
    }

    private func failImport(_ job: ImportJob, message: String) {
        if !job.snapshots.isEmpty {
            driver.recordImportWarning(SquirrelImporter.Report.mergeFailed(job.snapshots.count))
        }
        for request in job.requests { reply(request: request, ok: false, message: message) }
    }

    // MARK: - Replies and timeout

    private func reply(request: String?, ok: Bool, message: String?) {
        onReply?(DeployReply(request: request, ok: ok, message: message, log: driver.logDirectory.path))
    }

    private func armTimeout() {
        timeoutTask?.cancel()
        timeoutTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.timeout)
            guard !Task.isCancelled else { return }
            self.timeoutFired()
        }
    }

    /// Answers the waiting Settings request; the workspace lock stays with librime until
    /// its notification arrives, so a late success still releases it.
    private func timeoutFired() {
        timeoutTask = nil
        let requests = pendingRequests
        pendingRequests = []
        awaitingDeployAck = false
        isSyncing = false
        isDeploying = false
        for request in requests {
            reply(request: request, ok: false, message: "操作超时，可能仍在进行；请查看日志")
        }
    }
}
