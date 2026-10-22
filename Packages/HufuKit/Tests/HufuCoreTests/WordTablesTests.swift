import Foundation
import Testing
@testable import HufuCore

/// 词汇输入: which word table each (switch, 简繁模式) combination mounts.
struct WordTablesTests {
    /// The eight combinations and the tables they mount.
    static let matrix: [(enabled: Bool, mode: ScriptMode, mounted: [WordTables.Table])] = [
        (false, .mixed, []),
        (false, .tradOutput, []),
        (false, .tradOnly, []),
        (false, .simpOnly, []),
        (true, .mixed, [.simplified, .traditional]),
        (true, .tradOutput, [.converted]),
        (true, .tradOnly, [.traditional]),
        (true, .simpOnly, [.simplified]),
    ]

    @Test func mountMatrix() {
        for row in Self.matrix {
            #expect(WordTables.mounted(enabled: row.enabled, mode: row.mode) == row.mounted,
                    "\(row.enabled) \(row.mode)")
            let tags = WordTables.tags(enabled: row.enabled, mode: row.mode)
            #expect(tags.count == WordTables.Table.allCases.count)
            for table in WordTables.Table.allCases {
                let expected = row.mounted.contains(table) ? WordTables.activeTag : table.parkedTag
                #expect(tags[table.keypath] == expected, "\(row.enabled) \(row.mode) \(table)")
            }
        }
    }

    /// `abc` is the tag `abc_segmentor` emits; each parked tag is the translator's own
    /// name, which no segmentor produces.
    @Test func tagsAndKeypaths() {
        #expect(WordTables.activeTag == "abc")
        #expect(Set(WordTables.Table.allCases.map(\.parkedTag)).count == 3)
        for table in WordTables.Table.allCases {
            #expect(table.parkedTag == table.rawValue)
            #expect(table.parkedTag != WordTables.activeTag)
            #expect(table.keypath == "\(table.rawValue)/tag")
        }
    }

    /// The switch alone decides whether anything is mounted.
    @Test func switchOffMountsNothing() {
        for mode in ScriptMode.allCases {
            #expect(WordTables.mounted(enabled: false, mode: mode).isEmpty)
            #expect(WordTables.tags(enabled: false, mode: mode).values.allSatisfy { $0 != WordTables.activeTag })
        }
    }

    // MARK: - Generated layer

    /// Writes the mount through the settings store, the path the settings app takes.
    @Test func storeWritesAndReusesTheMount() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("hufu-words-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let shared = root.appendingPathComponent("shared")
        let paths = HufuPaths(userDataDir: root.appendingPathComponent("user"), sharedDataDir: shared)
        try FileManager.default.createDirectory(at: paths.stagingDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: shared, withIntermediateDirectories: true)
        // What the first deploy leaves behind: the built default.yaml names the schema.
        try "schema_list:\n  - schema: tigress\n".write(to: paths.builtConfig("default"), atomically: true, encoding: .utf8)
        let store = SettingsStore(paths: paths)
        let layers = ConfigLayers(paths: paths)

        #expect(try store.applyWordTables(enabled: true, mode: .mixed))
        #expect(layers.generatedValue(.schema("tigress"), keypath: "words_simp/tag") == .string("abc"))
        #expect(layers.generatedValue(.schema("tigress"), keypath: "words_trad/tag") == .string("words_trad"))
        #expect(layers.generatedValue(.schema("tigress"), keypath: "words_tradown/tag") == .string("abc"))
        // Written into the composed shim librime reads.
        let composed = try layers.composedPatch(.schema("tigress"))
        #expect(composed.contains { $0.key == "words_tradown/tag" && $0.value == .string("abc") })

        // Same state again: nothing to do, no deploy.
        #expect(try !store.applyWordTables(enabled: true, mode: .mixed))
        // Mode change rewrites, the switch off parks everything.
        #expect(try store.applyWordTables(enabled: true, mode: .tradOutput))
        #expect(layers.generatedValue(.schema("tigress"), keypath: "words_trad/tag") == .string("abc"))
        #expect(layers.generatedValue(.schema("tigress"), keypath: "words_simp/tag") == .string("words_simp"))
        #expect(try store.applyWordTables(enabled: false, mode: .tradOutput))
        #expect(layers.generatedValue(.schema("tigress"), keypath: "words_trad/tag") == .string("words_trad"))
        #expect(try !store.applyWordTables(enabled: false, mode: .mixed))
    }

    /// Before the first deploy there is no built default.yaml; the shipped one names the
    /// schema, so a switch flipped on a fresh install still lands.
    @Test func storeFallsBackToTheShippedSchemaList() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("hufu-words-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let shared = root.appendingPathComponent("shared")
        let paths = HufuPaths(userDataDir: root.appendingPathComponent("user"), sharedDataDir: shared)
        try FileManager.default.createDirectory(at: shared, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: paths.userDataDir, withIntermediateDirectories: true)
        try "schema_list:\n  - schema: tigress\n".write(to: shared.appendingPathComponent("default.yaml"), atomically: true, encoding: .utf8)
        let store = SettingsStore(paths: paths)
        #expect(store.primarySchema() == nil)
        #expect(try store.applyWordTables(enabled: true, mode: .simpOnly))
        #expect(ConfigLayers(paths: paths).generatedValue(.schema("tigress"), keypath: "words_simp/tag") == .string("abc"))
    }

    /// The shipped defaults park all three, so a workspace that never saw Hufu Settings
    /// still ships with 词汇输入 off.
    @Test func shippedDefaultsParkEveryTable() throws {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let layers = ConfigLayers(paths: HufuPaths(userDataDir: repo, sharedDataDir: repo.appendingPathComponent("SharedSupport")))
        let patch = try layers.defaultsPatch(.schema("tigress"))
        for table in WordTables.Table.allCases {
            #expect(patch.contains { $0.key == table.keypath && $0.value == .string(table.parkedTag) }, "\(table)")
        }
    }
}
