import Carbon
import Foundation

enum HufuIdentity {
    static let bundleID = "dev.yufan.hufu.inputmethod"
    static let inputModeID = "dev.yufan.hufu.inputmethod.hans"
    static var installedApp: URL {
        let user = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Input Methods/Hufu.app")
        let system = URL(fileURLWithPath: "/Library/Input Methods/Hufu.app")
        return FileManager.default.fileExists(atPath: user.path) || !FileManager.default.fileExists(atPath: system.path) ? user : system
    }
}

/// Text Input Sources registration (what System Settings › Keyboard › Input Sources lists).
enum InputSourceRegistrar {
    static func sources(includeAll: Bool = true) -> [TISInputSource] {
        let filter = [kTISPropertyBundleID as String: HufuIdentity.bundleID] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, includeAll)?.takeRetainedValue() as? [TISInputSource] else { return [] }
        return list
    }

    static func property(_ source: TISInputSource, _ key: CFString) -> Any? {
        guard let raw = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(raw).takeUnretainedValue()
    }

    static func status() -> String {
        let all = sources()
        guard !all.isEmpty else { return "not registered (run `hufu register`)" }
        func enabled(_ id: String) -> Bool? {
            all.first { property($0, kTISPropertyInputSourceID) as? String == id }
                .map { (property($0, kTISPropertyInputSourceIsEnabled) as? Bool) == true }
        }
        guard enabled(HufuIdentity.inputModeID) == true else {
            return "registered (enable it in System Settings › Keyboard › Input Sources)"
        }
        // The mode alone reports enabled right after a first install; macOS lists and selects
        // Hufu only once its input method is enabled too, which takes a log out (#8).
        return enabled(HufuIdentity.bundleID) == false
            ? "registered, pending (log out and back in once so macOS lists Hufu)" : "registered, enabled"
    }

    @discardableResult
    static func register(appURL: URL) -> OSStatus {
        TISRegisterInputSource(appURL as CFURL)
    }

    static func enable() -> Bool {
        var ok = false
        for source in sources() {
            let id = property(source, kTISPropertyInputSourceID) as? String
            if id == HufuIdentity.inputModeID || id == HufuIdentity.bundleID {
                ok = TISEnableInputSource(source) == noErr || ok
            }
        }
        return ok
    }
}
