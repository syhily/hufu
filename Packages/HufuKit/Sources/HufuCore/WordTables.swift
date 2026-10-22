public import Foundation

/// 词汇输入 (Settings › 输入习惯): which of the three word tables ships mounted.
///
/// `tigress.schema.yaml` declares three `table_translator@…`, each parked behind a tag no
/// segmentor produces. Mounting one means patching its `tag` to `abc`, the tag the
/// schema's segmentors emit; parking it puts the placeholder back.
///
/// The mount follows the *stored* 简繁模式. ⌃O / ⌃⇧4 flip librime's `simplification`
/// option for the session, which converts single characters at runtime; the word tables
/// stay as the mode's settings choose (the settings page says so).
public enum WordTables {
    /// What a mounted translator listens on — `abc_segmentor`'s tag.
    public static let activeTag = "abc"

    public enum Table: String, CaseIterable, Sendable {
        /// 简体词, keyed by the simplified code. 混打 and 只打简体.
        case simplified = "words_simp"
        /// 打简出繁: the simplified code, the word already converted by the build.
        case converted = "words_trad"
        /// 只打繁体: keyed by the traditional form's own code.
        case traditional = "words_tradown"

        /// Schema patch keypath for this translator's tag.
        public var keypath: String { "\(rawValue)/tag" }
        /// The tag it sits on while parked — no segmentor produces it.
        public var parkedTag: String { rawValue }
    }

    /// The tables a combination mounts, in a stable order.
    public static func mounted(enabled: Bool, mode: ScriptMode) -> [Table] {
        guard enabled else { return [] }
        switch mode {
        case .mixed: return [.simplified, .traditional]
        case .tradOutput: return [.converted]
        case .tradOnly: return [.traditional]
        case .simpOnly: return [.simplified]
        }
    }

    /// The three tags for one (switch, mode) combination: keypath → tag value.
    /// With the switch off nothing is mounted, whatever the mode.
    public static func tags(enabled: Bool, mode: ScriptMode) -> [String: String] {
        let mounted = Set(mounted(enabled: enabled, mode: mode))
        return Dictionary(uniqueKeysWithValues: Table.allCases.map { table in
            (table.keypath, mounted.contains(table) ? activeTag : table.parkedTag)
        })
    }
}
