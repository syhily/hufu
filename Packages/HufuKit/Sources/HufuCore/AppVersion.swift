public import Foundation
import Security

/// `MARKETING_VERSION` plus `CURRENT_PROJECT_VERSION`, compared numerically.
public struct AppVersion: Comparable, Sendable, CustomStringConvertible {
    public var parts: [Int]
    public var build: Int?
    public var string: String
    public var prerelease: [String]
    public var isPrerelease: Bool { !prerelease.isEmpty }

    public init(_ version: String, build: Int? = nil) {
        string = version
        let semantic = version.split(separator: "+", maxSplits: 1).first ?? "0"
        let components = semantic.split(separator: "-", maxSplits: 1)
        parts = (components.first ?? "0").split(separator: ".").map { Int($0) ?? 0 }
        prerelease = components.count > 1 ? components[1].split(separator: ".").map(String.init) : []
        self.build = build
    }

    /// The running app's version from its Info.plist.
    public static func current(_ bundle: Bundle = .main) -> AppVersion {
        let version = bundle.object(forInfoDictionaryKey: "HufuReleaseVersion") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let build = (bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String).flatMap(Int.init)
        return AppVersion(version, build: build)
    }

    public var description: String { build.map { "\(string) (\($0))" } ?? string }

    /// Team that signs release builds; ad-hoc development builds have no team.
    public static let signingTeamID = "PX694P4CGY"

    /// Whether this copy was signed by Hufu's team (a release), not an ad-hoc development
    /// build.
    public static func isDistributionBuild(_ bundle: Bundle = .main) -> Bool {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(bundle.bundleURL as CFURL, [], &code) == errSecSuccess, let code else { return false }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let dictionary = info as? [String: Any] else { return false }
        return dictionary[kSecCodeInfoTeamIdentifier as String] as? String == signingTeamID
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.parts.count, rhs.parts.count)
        for index in 0..<count {
            let left = index < lhs.parts.count ? lhs.parts[index] : 0
            let right = index < rhs.parts.count ? rhs.parts[index] : 0
            if left != right { return left < right }
        }
        if lhs.isPrerelease != rhs.isPrerelease { return lhs.isPrerelease }
        for (left, right) in zip(lhs.prerelease, rhs.prerelease) where left != right {
            let leftNumeric = left.allSatisfy { $0.isASCII && $0.isNumber }
            let rightNumeric = right.allSatisfy { $0.isASCII && $0.isNumber }
            if leftNumeric != rightNumeric { return leftNumeric }
            if leftNumeric, left.count != right.count { return left.count < right.count }
            return left < right
        }
        if lhs.prerelease.count != rhs.prerelease.count { return lhs.prerelease.count < rhs.prerelease.count }
        guard let left = lhs.build, let right = rhs.build else { return false }
        return left < right
    }

    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool { !(lhs < rhs) && !(rhs < lhs) }
}
