public import Foundation

/// Well-known locations. Everything Hufu writes lives under `userDataDir`; the
/// Squirrel directory is only ever read.
public struct HufuPaths: Sendable, Equatable {
    public var userDataDir: URL
    public var logDir: URL
    /// Read-only shipped data (Hufu.app/Contents/SharedSupport). Needed to compose the
    /// `hufu/defaults` layer; nil in contexts that only touch user layers.
    public var sharedDataDir: URL?

    public init(userDataDir: URL, logDir: URL? = nil, sharedDataDir: URL? = nil) {
        self.userDataDir = userDataDir
        self.logDir = logDir ?? userDataDir.appendingPathComponent("logs", isDirectory: true)
        self.sharedDataDir = sharedDataDir
    }

    /// `~/Library/Hufu/Rime`, overridable with `HUFU_USER_DIR` for tests and scripting.
    public static var standard: HufuPaths {
        let env = ProcessInfo.processInfo.environment
        if let override = env["HUFU_USER_DIR"], !override.isEmpty {
            return HufuPaths(userDataDir: URL(fileURLWithPath: (override as NSString).expandingTildeInPath, isDirectory: true))
        }
        let library = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library", isDirectory: true)
        return HufuPaths(
            userDataDir: library.appendingPathComponent("Hufu/Rime", isDirectory: true),
            logDir: library.appendingPathComponent("Logs/Hufu", isDirectory: true)
        )
    }

    /// The Squirrel (鼠须管) user directory, used as an import source only.
    public static var squirrelUserDir: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Rime", isDirectory: true)
    }

    public var stagingDir: URL { userDataDir.appendingPathComponent("build", isDirectory: true) }
    public var hufuDir: URL { userDataDir.appendingPathComponent("hufu", isDirectory: true) }
    public var importedDir: URL { hufuDir.appendingPathComponent("imported", isDirectory: true) }
    public var generatedDir: URL { hufuDir.appendingPathComponent("generated", isDirectory: true) }

    public func builtConfig(_ configID: String) -> URL {
        stagingDir.appendingPathComponent("\(configID).yaml")
    }
}

/// Rime's own file-name convention for the configs Hufu manages.
public enum ConfigTarget: Sendable, Hashable, CustomStringConvertible {
    /// `default.yaml`
    case `default`
    /// `<id>.schema.yaml`
    case schema(String)
    /// `hufu.yaml` — the frontend config; same keys as Squirrel's `squirrel.yaml`.
    case frontend

    /// Config id as used by `config_open` / the `build/` directory.
    public var configID: String {
        switch self {
        case .default: "default"
        case let .schema(id): "\(id).schema"
        case .frontend: "hufu"
        }
    }

    /// Base name of the `*.custom.yaml` patch file Rime auto-applies.
    public var customName: String {
        switch self {
        case .default: "default"
        case let .schema(id): id
        case .frontend: "hufu"
        }
    }

    public var description: String { configID }

    public init?(file: String, schemaID: String?) {
        switch file {
        case "default": self = .default
        case "frontend", "hufu", "squirrel": self = .frontend
        case "schema":
            guard let schemaID else { return nil }
            self = .schema(schemaID)
        default: return nil
        }
    }
}
