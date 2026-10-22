public import Foundation

/// How a deploy request asked the input method to apply work.
public enum DeployMode: String, Sendable, Equatable, CaseIterable {
    /// Rebuild schemas and the frontend config.
    case full
    /// Appearance-only changes may take the frontend fast path.
    case auto
    /// Merge user dictionaries; answered by the same result notification.
    case sync
    /// Deploy and then merge the import's snapshots.
    case `import`
}

/// The Settings app → input method request. One codec for both processes: names,
/// userInfo keys and modes live here, not as literals in each app.
public struct DeployRequest: Sendable, Equatable {
    public static let notification = Notification.Name("dev.yufan.hufu.reload")

    public var id: String
    public var mode: DeployMode

    public init(id: String = UUID().uuidString, mode: DeployMode) {
        self.id = id
        self.mode = mode
    }

    public init?(userInfo: [AnyHashable: Any]?) {
        guard let id = userInfo?["request"] as? String,
              let raw = userInfo?["mode"] as? String,
              let mode = DeployMode(rawValue: raw) else { return nil }
        self.id = id
        self.mode = mode
    }

    public var userInfo: [String: String] { ["request": id, "mode": mode.rawValue] }
}

/// Progress for one request, so Settings can name the stage and count schema targets.
public struct DeployProgress: Sendable, Equatable {
    public static let notification = Notification.Name("dev.yufan.hufu.deploy.progress")

    public var request: String?
    public var stage: String
    public var total: Int

    public init(request: String?, stage: String, total: Int) {
        self.request = request
        self.stage = stage
        self.total = total
    }

    public init?(userInfo: [AnyHashable: Any]?) {
        guard let stage = userInfo?["stage"] as? String else { return nil }
        self.request = userInfo?["request"] as? String
        self.stage = stage
        self.total = userInfo?["total"] as? Int ?? 0
    }

    public var userInfo: [String: Any] {
        var info: [String: Any] = ["stage": stage, "total": total]
        if let request { info["request"] = request }
        return info
    }
}

/// The input method's answer. `log` is always present so Settings can point the user at
/// the diagnostics folder even when the message is terse.
public struct DeployReply: Sendable, Equatable {
    public static let notification = Notification.Name("dev.yufan.hufu.deploy.result")

    public var request: String?
    public var ok: Bool
    public var message: String?
    public var log: String?

    public init(request: String?, ok: Bool, message: String? = nil, log: String? = nil) {
        self.request = request
        self.ok = ok
        self.message = message
        self.log = log
    }

    public init?(userInfo: [AnyHashable: Any]?) {
        guard let ok = userInfo?["ok"] as? Bool else { return nil }
        self.request = userInfo?["request"] as? String
        self.ok = ok
        self.message = userInfo?["message"] as? String
        self.log = userInfo?["log"] as? String
    }

    public var userInfo: [String: Any] {
        var info: [String: Any] = ["ok": ok]
        if let request { info["request"] = request }
        if let message { info["message"] = message }
        if let log { info["log"] = log }
        return info
    }
}

public enum DeployProtocol {
    /// One timeout for both sides. The input method answers a pending request after
    /// this long even if librime is still working; it keeps the workspace lock.
    public static let timeout: Duration = .seconds(180)
}
