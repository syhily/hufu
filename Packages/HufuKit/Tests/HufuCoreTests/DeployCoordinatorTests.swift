import Foundation
import Testing
@testable import HufuCore

@MainActor
struct DeployCoordinatorTests {
    final class FakeLock: DeployLock {}

    @MainActor
    final class FakeDriver: DeployDriver {
        var lockAvailable = true
        var dirty: [String] = ["tigress.schema"]
        var prepareError: Error?
        var frontendOK = true
        var maintenanceStarts = true
        var missing: [String] = []
        var syncOK = true
        let logDirectory = URL(fileURLWithPath: "/tmp/hufu-test")

        var prepareCount = 0
        var restartCount = 0
        var maintenanceChecks: [Bool] = []
        var markDeployedCount = 0
        var followCount = 0
        var syncPrepareCount = 0
        var restored: [String] = []
        var warnings: [String] = []
        var syncCount = 0

        func acquireLock() -> (any DeployLock)? { lockAvailable ? FakeLock() : nil }
        func prepareForDeploy() throws -> [String] {
            prepareCount += 1
            if let prepareError { throw prepareError }
            return dirty
        }
        func prepareForRestart() {}
        func restartEngine() { restartCount += 1 }
        func deployFrontend() -> Bool { frontendOK }
        func startMaintenance(fullCheck: Bool) -> Bool {
            maintenanceChecks.append(fullCheck)
            return maintenanceStarts
        }
        func markDeployed() { markDeployedCount += 1 }
        func followPrimarySchema() { followCount += 1 }
        func prepareForSync() { syncPrepareCount += 1 }
        func joinMaintenance() {}
        func restoreUserDictionary(named name: String) -> Bool {
            restored.append(name)
            return true
        }
        func syncUserData() -> Bool {
            syncCount += 1
            return syncOK
        }
        func recordImportWarning(_ message: String) { warnings.append(message) }
        func missingSchemas() -> [String] { missing }
    }

    private enum TestError: Error { case boom }

    /// Polls until `condition` holds or the deadline passes. Fixed sleeps were
    /// flaky in CI: 50 lock retries × 1 ms nominal can take far longer on a
    /// loaded runner, so assertions about "after the retries" must wait for the
    /// reply, not for the clock.
    private func waitUntil(_ condition: () -> Bool, timeout: Duration = .seconds(5)) async {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while !condition(), clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test func queuedDeploysRunOneAtATimeAndAnswerEachRequest() {
        let driver = FakeDriver()
        let coordinator = DeployCoordinator(driver: driver)
        var replies: [DeployReply] = []
        coordinator.onReply = { replies.append($0) }

        coordinator.enqueue(.init(request: "a", mode: .auto))
        #expect(coordinator.isBusy)
        #expect(replies.isEmpty)
        coordinator.enqueue(.init(request: "b", mode: .auto))
        #expect(coordinator.hasQueuedWork)

        coordinator.engineDidFinish(success: true)
        #expect(replies.map(\.request) == ["a"])
        #expect(driver.prepareCount == 2)
        #expect(coordinator.isBusy)

        coordinator.engineDidFinish(success: true)
        #expect(replies.map(\.request) == ["a", "b"])
        #expect(replies.allSatisfy { $0.ok })
        #expect(coordinator.isBusy == false)
        #expect(driver.markDeployedCount == 2)
    }

    @Test func frontendOnlyAutoSkipsTheEngineRestart() {
        let driver = FakeDriver()
        driver.dirty = ["hufu"]
        let coordinator = DeployCoordinator(driver: driver)
        var replies: [DeployReply] = []
        coordinator.onReply = { replies.append($0) }

        coordinator.enqueue(.init(request: "a", mode: .auto))
        #expect(replies.map(\.request) == ["a"])
        #expect(replies.first?.ok == true)
        #expect(driver.restartCount == 0)
        #expect(driver.markDeployedCount == 1)
        #expect(coordinator.isBusy == false)
    }

    @Test func missingSchemaFailsTheReportedResult() {
        let driver = FakeDriver()
        driver.missing = ["tigress"]
        let coordinator = DeployCoordinator(driver: driver)
        var replies: [DeployReply] = []
        coordinator.onReply = { replies.append($0) }

        coordinator.enqueue(.init(request: "a", mode: .full))
        coordinator.engineDidFinish(success: true)
        #expect(replies.first?.ok == false)
        #expect(replies.first?.message?.contains("tigress") == true)
        #expect(driver.markDeployedCount == 0)
        #expect(driver.followCount == 0)
    }

    @Test func importSnapshotsRideTheirDeployAndDedupe() {
        let driver = FakeDriver()
        let coordinator = DeployCoordinator(driver: driver)
        var replies: [DeployReply] = []
        coordinator.onReply = { replies.append($0) }

        coordinator.enqueue(.init(request: "deploy", mode: .full))
        coordinator.enqueue(.init(request: "import", mode: .import, importedSnapshots: ["a", "a"]))
        #expect(coordinator.isBusy)

        coordinator.engineDidFinish(success: true, schemasDeployed: true)
        #expect(replies.map(\.request) == ["deploy"])
        #expect(coordinator.isBusy)

        coordinator.engineDidFinish(success: true, schemasDeployed: true)
        #expect(driver.restored == ["a"])
        #expect(driver.syncCount == 1)
        #expect(coordinator.isSyncing)

        coordinator.engineDidFinish(success: true)
        #expect(replies.map(\.request) == ["deploy", "import"])
        #expect(replies.last?.ok == true)
        #expect(coordinator.isBusy == false)
    }

    @Test func lockContentionFailsTheQueueAfterRetries() async {
        let driver = FakeDriver()
        driver.lockAvailable = false
        let coordinator = DeployCoordinator(driver: driver, retryDelay: .milliseconds(1))
        var replies: [DeployReply] = []
        coordinator.onReply = { replies.append($0) }

        coordinator.enqueue(.init(request: "a", mode: .full))
        await waitUntil { replies.count == 1 }
        #expect(replies.count == 1)
        #expect(replies.first?.ok == false)
        #expect(replies.first?.message?.contains("占用") == true)
        #expect(coordinator.isBusy == false)
    }

    @Test func lockContentionAnswersAnImportOnce() async {
        let driver = FakeDriver()
        driver.lockAvailable = false
        let coordinator = DeployCoordinator(driver: driver, retryDelay: .milliseconds(1))
        var replies: [DeployReply] = []
        coordinator.onReply = { replies.append($0) }

        coordinator.enqueue(.init(request: "import", mode: .import, importedSnapshots: ["a"]))
        await waitUntil { replies.count == 1 }
        #expect(replies.count == 1)
        #expect(replies.first?.request == "import")
        #expect(driver.warnings.count == 1)
    }

    @Test func timeoutAnswersButKeepsTheWorkspaceLock() async {
        let driver = FakeDriver()
        let coordinator = DeployCoordinator(driver: driver, timeout: .milliseconds(20))
        var replies: [DeployReply] = []
        coordinator.onReply = { replies.append($0) }

        coordinator.enqueue(.init(request: "a", mode: .full))
        #expect(coordinator.isBusy)
        await waitUntil { replies.count == 1 }
        #expect(replies.count == 1)
        #expect(replies.first?.ok == false)
        #expect(replies.first?.message?.contains("超时") == true)
        #expect(coordinator.isBusy)

        coordinator.engineDidFinish(success: true)
        #expect(coordinator.isBusy == false)
        #expect(replies.count == 1)
    }

    @Test func prepareFailureRepliesAndLeavesTheEngineUntouched() {
        let driver = FakeDriver()
        driver.prepareError = TestError.boom
        let coordinator = DeployCoordinator(driver: driver)
        var replies: [DeployReply] = []
        coordinator.onReply = { replies.append($0) }

        coordinator.enqueue(.init(request: "a", mode: .full))
        #expect(replies.first?.ok == false)
        #expect(driver.restartCount == 0)
        #expect(coordinator.isBusy == false)
    }
}
