public import Foundation

/// The user's own settings, independent of where each one is stored.
///
/// Feature flags live in `hufu/features.json`; their schema consequences (词汇输入's
/// translator tags) live in the generated patch layer. Calls that change a setting
/// write both sides in one place, so views and the input method never have to know
/// which plane a concept happens to use.
public struct UserSettings: Sendable {
    /// The OpenCC tables the product offers. The dedicated 简繁 page mirrors these
    /// values; writes with anything else are refused.
    public static let scriptVariants: Set<String> = [
        "st_tu.json", "s2t.json", "s2tw.json", "s2twp.json", "s2hk.json",
    ]

    public struct Update: Sendable, Equatable {
        public var featuresChanged: Bool
        public var schemaChanged: Bool

        public init(featuresChanged: Bool, schemaChanged: Bool) {
            self.featuresChanged = featuresChanged
            self.schemaChanged = schemaChanged
        }
    }

    public let paths: HufuPaths
    public let store: SettingsStore

    public init(paths: HufuPaths, store: SettingsStore? = nil) {
        self.paths = paths
        self.store = store ?? SettingsStore(paths: paths)
    }

    public var features: HufuFeatures { HufuFeatures.load(paths) }

    /// `simplification/opencc_config` is owned by the generated layer; features.json's
    /// `tradVariant` is only the fallback for files written by older versions.
    public var scriptVariant: String {
        guard let schema = store.schemaID() else { return legacyScriptVariant }
        let target = ConfigTarget.schema(schema)
        let keypath = "simplification/opencc_config"
        if let value = store.layers.generatedValue(target, keypath: keypath)?.stringValue { return value }
        if let value = store.built(target)?.value(at: keypath)?.stringValue { return value }
        return legacyScriptVariant
    }

    private var legacyScriptVariant: String {
        let stored = features.tradVariant
        return stored.hasSuffix(".json") ? stored : stored + ".json"
    }

    /// Writes feature flags and applies the schema mount those flags imply. Returns
    /// which planes changed so the caller can schedule a deploy only when needed.
    @discardableResult
    public func updateFeatures(_ body: (inout HufuFeatures) -> Void) throws -> Update {
        var features = self.features
        let before = features
        body(&features)
        // Consent to send text is given for one host; a new endpoint needs it again.
        if URL(string: features.aiBaseURL)?.host() != URL(string: before.aiBaseURL)?.host() {
            features.aiRemoteAllowed = false
        }
        guard features != before else { return Update(featuresChanged: false, schemaChanged: false) }
        try features.save(paths)
        let schemaChanged = try applyWordTables(features, before: before)
        return Update(featuresChanged: true, schemaChanged: schemaChanged)
    }

    /// The deploy-time reconciliation run at launch: a crash between flipping the switch
    /// and deploying must not leave the shipped word table mounted.
    @discardableResult
    public func reconcileSchema() throws -> Bool {
        let features = self.features
        return try store.applyWordTables(enabled: features.wordsEnabled, mode: features.scriptMode)
    }

    /// Writes the OpenCC standard into the generated layer, where it takes effect.
    @discardableResult
    public func setScriptVariant(_ value: String) throws -> Bool {
        guard Self.scriptVariants.contains(value), let schema = store.schemaID() else { return false }
        let target = ConfigTarget.schema(schema)
        let keypath = "simplification/opencc_config"
        let current = store.layers.generatedValue(target, keypath: keypath)?.stringValue
            ?? store.built(target)?.value(at: keypath)?.stringValue
        guard current != value else { return false }
        try store.layers.updateGenerated(target) { patch in
            if let index = patch.firstIndex(where: { $0.key == keypath }) {
                patch[index].value = .string(value)
            } else {
                patch.append(.init(keypath, .string(value)))
            }
        }
        return true
    }

    private func applyWordTables(_ features: HufuFeatures, before: HufuFeatures) throws -> Bool {
        guard features.wordsEnabled != before.wordsEnabled || features.scriptMode != before.scriptMode else {
            return false
        }
        return try store.applyWordTables(enabled: features.wordsEnabled, mode: features.scriptMode)
    }
}
