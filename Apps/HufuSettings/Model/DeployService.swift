import HufuCore
import AppKit

/// Where the installed pieces live.
enum Locations {
    /// The input method bundle: the one we are embedded in, else the installed copy.
    static var inputMethodApp: URL? {
        let embedding = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        if embedding.pathExtension == "app",
           FileManager.default.fileExists(atPath: embedding.appendingPathComponent("Contents/Helpers/hufu").path) {
            return embedding
        }
        // Per-user dev install first, then the system-wide .pkg location.
        let candidates = [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Input Methods/Hufu.app"),
            URL(fileURLWithPath: "/Library/Input Methods/Hufu.app"),
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    static var cli: URL? { inputMethodApp?.appendingPathComponent("Contents/Helpers/hufu") }

    static var sharedSupport: URL? {
        if let app = inputMethodApp { return app.appendingPathComponent("Contents/SharedSupport") }
        // Development: repository build output.
        let env = ProcessInfo.processInfo.environment["HUFU_SHARED_DIR"]
        return env.map { URL(fileURLWithPath: $0) }
    }

    static let inputMethodBundleID = "dev.yufan.hufu.inputmethod"
}

/// Deploys through the running input method (so its sessions reload immediately), or
/// through the bundled CLI when the input method is not running.
@MainActor
final class DeployService {
    enum Outcome: Equatable {
        case success
        case failure(String)
    }

    struct CommandResult {
        var ok: Bool
        var output: String
    }

    let paths: HufuPaths
    /// Injected so a test (or UI automation) can replace the notification transport.
    let client: DeployClient

    init(paths: HufuPaths, client: DeployClient = DeployClient()) {
        self.paths = paths
        self.client = client
    }

    var inputMethodIsRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: Locations.inputMethodBundleID).isEmpty
    }

    /// A sandboxed workspace (HUFU_USER_DIR, used by UI automation) is never handed to
    /// the running input method, which serves the real one.
    var usesInputMethod: Bool {
        inputMethodIsRunning && ProcessInfo.processInfo.environment["HUFU_USER_DIR"] == nil
    }

    func deploy(automatic: Bool = false, progress: @escaping @MainActor (String, Int) -> Void = { _, _ in }) async -> Outcome {
        if usesInputMethod {
            // Never start a second writer on timeout: the input method may still be
            // deploying. Report the unknown outcome instead.
            return await requestViaInputMethod(mode: automatic ? .auto : .full, progress: progress)
                ?? .failure("输入法未在 3 分钟内返回结果，可能仍在应用设置；请稍后查看日志 \(paths.logDir.path)")
        }
        let result = await run(["deploy"])
        return result.ok ? .success : .failure(Self.summarize(result.output))
    }

    /// Merges user dictionaries with the sync directory. The running input method holds
    /// the userdbs open, so it must do the export itself; the CLI only works without it.
    func sync() async -> Outcome {
        if usesInputMethod {
            return await requestViaInputMethod(mode: .sync, progress: { _, _ in })
                ?? .failure("输入法未在 3 分钟内返回同步结果，可能仍在同步；请稍后查看日志 \(paths.logDir.path)")
        }
        let result = await run(["sync"])
        return result.ok ? .success : .failure(Self.summarize(result.output))
    }

    /// After `import-squirrel --no-deploy`: the running input method deploys and merges the
    /// imported snapshots itself (a second process cannot open its user dictionaries).
    func deployImportedViaInputMethod() async -> Outcome {
        await requestViaInputMethod(mode: .import, progress: { _, _ in })
            ?? .failure("输入法未在 3 分钟内返回导入结果，可能仍在处理；请稍后查看日志 \(paths.logDir.path)")
    }

    private func requestViaInputMethod(mode: DeployMode, progress: @escaping @MainActor (String, Int) -> Void) async -> Outcome? {
        let reply = await client.send(DeployRequest(mode: mode)) { update in
            progress(update.stage, update.total)
        }
        guard let reply else { return nil }
        guard !reply.ok else { return .success }
        let message = reply.message ?? "设置未能生效"
        return .failure("\(message)（日志：\(reply.log ?? paths.logDir.path)）")
    }

    /// Runs the bundled `hufu` CLI off the main thread.
    func run(_ arguments: [String]) async -> CommandResult {
        guard let cli = Locations.cli else {
            return CommandResult(ok: false, output: "未找到 Hufu 输入法（~/Library/Input Methods/Hufu.app），请先安装。")
        }
        let userDir = paths.userDataDir.path
        return await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = cli
            process.arguments = arguments + ["--user-dir", userDir]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                return CommandResult(ok: process.terminationStatus == 0, output: String(decoding: data, as: UTF8.self))
            } catch {
                return CommandResult(ok: false, output: String(describing: error))
            }
        }.value
    }

    static func summarize(_ output: String) -> String {
        let lines = output.split(separator: "\n").filter { !$0.hasPrefix("I20") && !$0.hasPrefix("W20") && !$0.contains("Logging before") }
        return lines.suffix(4).joined(separator: "\n")
    }
}
