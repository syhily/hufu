public import Foundation

/// Reads effective values from the deployed `build/` output and writes changes into
/// the generated layer. Does not link librime; deployment is requested separately.
public struct SettingsStore: Sendable {
    public let paths: HufuPaths
    public let layers: ConfigLayers
    public let catalog: SettingCatalog

    public init(paths: HufuPaths, catalog: SettingCatalog = .bundled) {
        self.paths = paths
        self.layers = ConfigLayers(paths: paths)
        self.catalog = catalog
    }

    // MARK: - Reading

    /// The merged config librime produced for `target`, or nil before the first deploy.
    public func built(_ target: ConfigTarget) -> ConfigValue? {
        try? ConfigValue.load(contentsOf: paths.builtConfig(target.configID))
    }

    /// Schemas enabled in `schema_list`, in order.
    public func enabledSchemas() -> [String] {
        (built(.default)?.value(at: "schema_list")?.listValue ?? []).compactMap { $0["schema"]?.stringValue }
    }

    /// The first enabled schema is what the catalog's `schema`-file settings target.
    public func primarySchema() -> String? { enabledSchemas().first }

    /// Effective value: pending generated value, else deployed value, else catalog default.
    public func value(for setting: SettingCatalog.Setting, schemaID: String? = nil) -> ConfigValue? {
        guard let target = setting.target(schemaID: schemaID ?? primarySchema()) else { return setting.default }
        if let items = setting.listItems {
            let current = list(target: target, keypath: setting.keypath)
            return .bool(items.allSatisfy { item in current.contains { Self.sameValue($0, item) } })
        }
        guard let keypath = resolve(setting.keypath, target: target) else { return setting.default }
        if let pending = layers.generatedValue(target, keypath: keypath) { return normalize(pending, setting) }
        if let value = built(target)?.value(at: keypath) { return normalize(value, setting) }
        // `style/hufu/<key>` not set yet: show what is in effect from the plain style
        // (e.g. an imported Squirrel style) rather than the catalog default.
        if keypath.hasPrefix("style/hufu/"),
           let inherited = previewFrontend().value(at: "style/" + keypath.dropFirst("style/hufu/".count)) {
            return normalize(inherited, setting)
        }
        return setting.default
    }

    /// Rime stores `switches/@name=…/reset` as 0/1; a boolean control expects a bool.
    private func normalize(_ value: ConfigValue, _ setting: SettingCatalog.Setting) -> ConfigValue {
        guard setting.type == .bool, let int = value.intValue, int == 0 || int == 1 else { return value }
        return .bool(int == 1)
    }

    /// Current value of a list node, preferring a pending generated replacement.
    public func list(target: ConfigTarget, keypath: String) -> [ConfigValue] {
        (layers.generatedValue(target, keypath: keypath) ?? built(target)?.value(at: keypath))?.listValue ?? []
    }

    /// Replaces `@field=value` selectors (e.g. `switches/@name=emoji/reset`) with the
    /// concrete list index found in the deployed config. Returns nil when not found.
    public func resolve(_ keypath: String, target: ConfigTarget) -> String? {
        guard keypath.contains("@"), keypath.contains("=") else { return keypath }
        var resolved: [String] = []
        for component in keypath.split(separator: "/").map(String.init) {
            guard component.hasPrefix("@"), let eq = component.firstIndex(of: "=") else {
                resolved.append(component)
                continue
            }
            let field = String(component[component.index(after: component.startIndex)..<eq])
            let wanted = String(component[component.index(after: eq)...])
            let parent = resolved.joined(separator: "/")
            let entries = built(target)?.value(at: parent)?.listValue ?? []
            guard let index = entries.firstIndex(where: { $0[field]?.stringValue == wanted }) else { return nil }
            resolved.append("@\(index)")
        }
        return resolved.joined(separator: "/")
    }

    // MARK: - Writing

    public enum WriteError: Error, CustomStringConvertible {
        case unknownTarget(String)
        case outOfRange(String)
        public var description: String {
            switch self {
            case let .unknownTarget(id): "no config target for setting \(id)"
            case let .outOfRange(id): "value out of range for \(id)"
            }
        }
    }

    /// Records a new value in the generated layer. Call deploy afterwards.
    public func set(_ value: ConfigValue, for setting: SettingCatalog.Setting, schemaID: String? = nil) throws {
        guard let target = setting.target(schemaID: schemaID ?? primarySchema()) else {
            throw WriteError.unknownTarget(setting.id)
        }
        if let number = value.doubleValue {
            if let min = setting.min, number < min { throw WriteError.outOfRange(setting.id) }
            if let max = setting.max, number > max { throw WriteError.outOfRange(setting.id) }
        }
        if let toggled = setting.listItems, let enabled = value.boolValue {
            var entries = list(target: target, keypath: setting.keypath)
            entries.removeAll { entry in toggled.contains { Self.sameValue(entry, $0) } }
            if enabled { entries.append(contentsOf: toggled) }
            try layers.setGenerated(target, keypath: setting.keypath, value: .list(entries))
            return
        }
        guard let keypath = resolve(setting.keypath, target: target) else { throw WriteError.unknownTarget(setting.id) }
        try layers.setGenerated(target, keypath: keypath, value: value)
    }

    /// Catalog values and YAML maps may list keys in different orders; compare them by
    /// meaning so a toggle recognises the binding it wrote.
    static func sameValue(_ lhs: ConfigValue, _ rhs: ConfigValue) -> Bool {
        switch (lhs, rhs) {
        case let (.map(left), .map(right)):
            return left.count == right.count && left.allSatisfy { entry in
                right.contains { $0.key == entry.key && sameValue($0.value, entry.value) }
            }
        case let (.list(left), .list(right)):
            return left.count == right.count && zip(left, right).allSatisfy { sameValue($0, $1) }
        default:
            return lhs == rhs
        }
    }

    /// Drops the generated override so the imported / shipped value applies again.
    public func reset(_ setting: SettingCatalog.Setting, schemaID: String? = nil) throws {
        guard let target = setting.target(schemaID: schemaID ?? primarySchema()) else { return }
        guard let keypath = resolve(setting.keypath, target: target) else { return }
        try layers.setGenerated(target, keypath: keypath, value: nil)
    }

    /// Whether the generated layer overrides this setting.
    public func isCustomized(_ setting: SettingCatalog.Setting, schemaID: String? = nil) -> Bool {
        guard let target = setting.target(schemaID: schemaID ?? primarySchema()) else { return false }
        guard let keypath = resolve(setting.keypath, target: target) else { return false }
        return layers.generatedValue(target, keypath: keypath) != nil
    }

    // MARK: - 词汇输入

    /// Writes the word-table mount for one (switch, mode) combination into the generated
    /// layer of the primary schema. Returns true when an entry changed — the caller then
    /// has to deploy (the app's normal auto-deploy does it).
    @discardableResult
    public func applyWordTables(enabled: Bool, mode: ScriptMode) throws -> Bool {
        guard let schema = primarySchema() ?? shippedSchema() else { return false }
        let target = ConfigTarget.schema(schema)
        let desired = WordTables.tags(enabled: enabled, mode: mode)
        let current = try layers.generatedPatch(target)
        let satisfied = desired.allSatisfy { keypath, tag in
            current.last { $0.key == keypath }?.value == .string(tag)
        }
        guard !satisfied else { return false }
        try layers.updateGenerated(target) { patch in
            for (keypath, tag) in desired.sorted(by: { $0.key < $1.key }) {
                if let index = patch.firstIndex(where: { $0.key == keypath }) {
                    patch[index].value = .string(tag)
                } else {
                    patch.append(.init(keypath, .string(tag)))
                }
            }
        }
        return true
    }

    /// Before the first deploy there is no built `default.yaml` to read the schema list
    /// from; the shipped one still names the primaries the workspace will build.
    private func shippedSchema() -> String? {
        guard let shared = paths.sharedDataDir,
              let config = try? ConfigValue.load(contentsOf: shared.appendingPathComponent("default.yaml")) else { return nil }
        return config.value(at: "schema_list")?.listValue?.first?["schema"]?.stringValue
    }
}
