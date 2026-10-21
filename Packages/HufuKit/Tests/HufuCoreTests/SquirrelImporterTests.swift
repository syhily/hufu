import Foundation
import Testing
@testable import HufuCore

struct SquirrelImporterTests {
    let source: URL
    let paths: HufuPaths

    init() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("hufu-import-\(UUID().uuidString)")
        source = root.appendingPathComponent("Rime")
        paths = HufuPaths(userDataDir: root.appendingPathComponent("Hufu"))
        let fm = FileManager.default
        try fm.createDirectory(at: source.appendingPathComponent("build"), withIntermediateDirectories: true)
        try fm.createDirectory(at: source.appendingPathComponent("lua"), withIntermediateDirectories: true)
        try fm.createDirectory(at: source.appendingPathComponent("rime_ice.userdb"), withIntermediateDirectories: true)
        try fm.createDirectory(at: source.appendingPathComponent("sync/abc-123"), withIntermediateDirectories: true)
        try fm.createDirectory(at: source.appendingPathComponent(".specstory"), withIntermediateDirectories: true)
        let files: [String: String] = [
            "default.custom.yaml": "# mine\npatch:\n  menu/page_size: 9\n",
            "rime_ice.custom.yaml": "patch:\n  speller/algebra: [\"derive/^l/n/\"]\n",
            "squirrel.custom.yaml": "patch:\n  style/color_scheme: ink\n  app_options:\n    com.apple.Terminal: {ascii_mode: true}\n",
            "squirrel.yaml": "preset_color_schemes:\n  ink:\n    name: Ink\n    back_color: 0x000000\n",
            "rime_ice.schema.yaml": "schema: {schema_id: rime_ice}\n",
            "custom_phrase.txt": "Hufu\thufu\t1\n",
            "installation.yaml": "installation_id: abc-123\n",
            "user.yaml": "var: {}\n",
            "build/default.yaml": "x: 1\n",
            "lua/date.lua": "-- lua\n",
            "rime_ice.userdb/LOCK": "",
            "sync/abc-123/rime_ice.userdb.txt": "# snapshot\n",
            ".specstory/history.md": "private\n",
            "README.md": "# readme\n",
            "go.work": "go 1.22\n",
        ]
        for (path, text) in files {
            try text.write(to: source.appendingPathComponent(path), atomically: true, encoding: .utf8)
        }
    }

    /// Snapshot of every file under the source with its modification date.
    private func fingerprint() throws -> [String: Date] {
        var result: [String: Date] = [:]
        let enumerator = FileManager.default.enumerator(at: source, includingPropertiesForKeys: [.contentModificationDateKey])!
        for case let url as URL in enumerator {
            result[url.path] = try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        }
        return result
    }

    @Test func plansSkipsAndLayers() throws {
        let plan = try SquirrelImporter(paths: paths, source: source).plan()
        #expect(plan.copies.sorted() == ["custom_phrase.txt", "lua", "rime_ice.schema.yaml"])
        // Only Squirrel's frontend patch (appearance) is carried over.
        #expect(plan.customs.map(\.0) == ["squirrel.custom.yaml"])
        #expect(plan.customs.map(\.1) == [.frontend])
        let skipped = plan.actions.compactMap { if case let .skip(path, _) = $0 { path } else { nil } }
        #expect(Set(skipped) == [
            "build", "installation.yaml", "user.yaml", "squirrel.yaml", "rime_ice.userdb", ".specstory",
            "README.md", "go.work", "default.custom.yaml", "rime_ice.custom.yaml",
        ])
    }

    @Test func importsWithoutTouchingSource() throws {
        let before = try fingerprint()
        let importer = SquirrelImporter(paths: paths, source: source)
        let report = try importer.execute(importer.plan())
        #expect(try fingerprint() == before)

        let layers = ConfigLayers(paths: paths)
        // The Squirrel frontend patch is copied byte-for-byte; scheme patches stay behind.
        #expect(try Data(contentsOf: layers.importedURL(.frontend)) == Data(contentsOf: source.appendingPathComponent("squirrel.custom.yaml")))
        #expect(!FileManager.default.fileExists(atPath: layers.importedURL(.default).path))
        #expect(!FileManager.default.fileExists(atPath: paths.userDataDir.appendingPathComponent("default.custom.yaml").path))
        #expect(!FileManager.default.fileExists(atPath: layers.shimURL(.schema("rime_ice")).path))
        #expect(report.customLayers.count == 1)
        #expect(report.customLayers.first?.hasPrefix("squirrel.custom.yaml") == true)
        // Snapshots staged for sync, live LevelDB and build output left behind.
        #expect(FileManager.default.fileExists(atPath: paths.userDataDir.appendingPathComponent("sync/abc-123/rime_ice.userdb.txt").path))
        #expect(!FileManager.default.fileExists(atPath: paths.userDataDir.appendingPathComponent("rime_ice.userdb").path))
        #expect(!FileManager.default.fileExists(atPath: paths.userDataDir.appendingPathComponent("build/default.yaml").path))
        #expect(!FileManager.default.fileExists(atPath: paths.userDataDir.appendingPathComponent("installation.yaml").path))
        // Phrase tables are merged into huma_custom instead of being copied.
        let phrases = CustomPhrases.loadDictionary(from: paths.userDataDir.appendingPathComponent(PhraseTable.hufu.fileName))
        #expect(phrases.phrases.map(\.text) == ["Hufu"])
        #expect(!FileManager.default.fileExists(atPath: paths.userDataDir.appendingPathComponent("custom_phrase.txt").path))
        // Referenced color scheme only defined in squirrel.yaml is carried over.
        #expect(report.colorSchemesCarriedOver == ["ink"])
        #expect(layers.generatedValue(.frontend, keypath: "preset_color_schemes/ink")?["name"] == "Ink")
        #expect(FileManager.default.fileExists(atPath: paths.hufuDir.appendingPathComponent("import-report.json").path))
    }

    @Test func reimportReplacesPreviousFrontendPatch() throws {
        let importer = SquirrelImporter(paths: paths, source: source)
        try importer.execute(importer.plan())
        try "patch:\n  style/color_scheme: mac_light\n".write(to: source.appendingPathComponent("squirrel.custom.yaml"), atomically: true, encoding: .utf8)
        try importer.execute(importer.plan())
        let text = try String(contentsOf: ConfigLayers(paths: paths).importedURL(.frontend), encoding: .utf8)
        #expect(text.contains("mac_light"))
    }
}

extension SquirrelImporterTests {
    @Test func refusesSameDirectoryAndWarnsWithoutSnapshots() throws {
        let selfImport = SquirrelImporter(paths: HufuPaths(userDataDir: source), source: source)
        #expect(throws: SquirrelImporter.ImportError.self) { try selfImport.execute(selfImport.plan()) }

        try FileManager.default.removeItem(at: source.appendingPathComponent("sync/abc-123/rime_ice.userdb.txt"))
        let importer = SquirrelImporter(paths: paths, source: source)
        let report = try importer.execute(importer.plan())
        #expect(report.warnings.count == 1)
    }

    @Test func reimportBacksUpEditedImportedLayer() throws {
        let importer = SquirrelImporter(paths: paths, source: source)
        try importer.execute(importer.plan())
        let imported = ConfigLayers(paths: paths).importedURL(.frontend)
        try "# edited in Hufu\npatch: {}\n".write(to: imported, atomically: true, encoding: .utf8)
        try importer.execute(importer.plan())
        let backups = FileManager.default.enumerator(atPath: paths.hufuDir.appendingPathComponent("backup").path)?.allObjects as? [String] ?? []
        #expect(backups.contains { $0.hasSuffix(imported.lastPathComponent) })
    }
}

extension SquirrelImporterTests {
    @Test func reimportMergesPhraseTablesInsteadOfOverwriting() throws {
        try "# Rime table\n#@/db_type\ttabledb\n罗磊\tll\n".write(to: source.appendingPathComponent("custom_phrase_double.txt"), atomically: true, encoding: .utf8)
        let importer = SquirrelImporter(paths: paths, source: source)
        try importer.execute(importer.plan())
        let table = paths.userDataDir.appendingPathComponent(PhraseTable.hufu.fileName)
        var edited = CustomPhrases.loadDictionary(from: table)
        _ = edited.add(.init(text: "Hufu 新增", code: "xz"))
        try edited.saveDictionary(to: table)
        try importer.execute(importer.plan())
        let texts = CustomPhrases.loadDictionary(from: table).phrases.map(\.text)
        #expect(texts.contains("罗磊") && texts.contains("Hufu 新增") && texts.contains("Hufu"))
    }
}

extension SquirrelImporterTests {
    @Test(arguments: ["absolute", "relative", "tilde"])
    func importsOnlyConfiguredSyncDirectory(kind: String) throws {
        let fm = FileManager.default
        let external = source.deletingLastPathComponent().appendingPathComponent("External Sync")
        try fm.createDirectory(at: external.appendingPathComponent("device"), withIntermediateDirectories: true)
        let snapshot = external.appendingPathComponent("device/test.userdb.txt")
        try "# synthetic snapshot\n".write(to: snapshot, atomically: true, encoding: .utf8)
        let before = try Data(contentsOf: snapshot)
        let path: String
        switch kind {
        case "relative": path = "../External Sync"
        case "tilde":
            let home = fm.homeDirectoryForCurrentUser.path
            // A temporary fixture under home exercises ~ without reading user data.
            let local = fm.homeDirectoryForCurrentUser.appendingPathComponent(".hufu-sync-test-\(UUID().uuidString)")
            try fm.createSymbolicLink(at: local, withDestinationURL: external)
            defer { try? fm.removeItem(at: local) }
            path = "~" + local.path.dropFirst(home.count)
            try verifyConfiguredSync(path, expected: before)
            return
        default: path = external.path
        }
        try verifyConfiguredSync(path, expected: before)
        #expect(try Data(contentsOf: snapshot) == before)
    }

    private func verifyConfiguredSync(_ path: String, expected: Data) throws {
        let yaml = try ConfigValue.map([.init("sync_dir", .string(path))]).yamlString()
        try yaml.write(to: source.appendingPathComponent("installation.yaml"), atomically: true, encoding: .utf8)
        let importer = SquirrelImporter(paths: paths, source: source)
        let report = try importer.execute(importer.plan())
        #expect(report.snapshots == ["device/test.userdb.txt"])
        #expect(report.warnings.isEmpty)
        #expect(try Data(contentsOf: paths.userDataDir.appendingPathComponent("sync/device/test.userdb.txt")) == expected)
        #expect(!FileManager.default.fileExists(atPath: paths.userDataDir.appendingPathComponent("sync/abc-123/rime_ice.userdb.txt").path))
    }

    @Test(arguments: ["missing", "file", "denied", "overlap"])
    func warnsWhenConfiguredSnapshotsCannotBeRead(kind: String) throws {
        let fm = FileManager.default
        let external = kind == "overlap" ? paths.userDataDir : source.deletingLastPathComponent().appendingPathComponent("unreadable")
        if kind == "file" { try "not a folder".write(to: external, atomically: true, encoding: .utf8) }
        if kind == "denied" {
            try fm.createDirectory(at: external, withIntermediateDirectories: true)
            try fm.setAttributes([.posixPermissions: 0], ofItemAtPath: external.path)
        }
        defer { if kind == "denied" { try? fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: external.path) } }
        try ConfigValue.map([.init("sync_dir", .string(external.path))]).yamlString()
            .write(to: source.appendingPathComponent("installation.yaml"), atomically: true, encoding: .utf8)
        let importer = SquirrelImporter(paths: paths, source: source)
        let report = try importer.execute(importer.plan())
        #expect(report.snapshots.isEmpty)
        #expect(!report.warnings.isEmpty)
    }
}

extension SquirrelImporterTests {
    @Test func laterMergeFailuresAreRecordedOnceInTheReport() throws {
        let importer = SquirrelImporter(paths: paths, source: source)
        _ = try importer.execute(importer.plan())
        let warning = SquirrelImporter.Report.mergeFailed(1)
        SquirrelImporter.Report.appendWarning(warning, paths: paths)
        SquirrelImporter.Report.appendWarning(warning, paths: paths)
        #expect(SquirrelImporter.Report.load(paths)?.warnings.filter { $0 == warning }.count == 1)
        // A new import starts a fresh report.
        _ = try importer.execute(importer.plan())
        #expect(SquirrelImporter.Report.load(paths)?.warnings.contains(warning) == false)
    }
}

extension SquirrelImporterTests {
    @Test func mergeFailureWarningKeepsOnlyTheLatestCount() throws {
        let importer = SquirrelImporter(paths: paths, source: source)
        _ = try importer.execute(importer.plan())
        SquirrelImporter.Report.appendWarning(SquirrelImporter.Report.mergeFailed(2), paths: paths)
        SquirrelImporter.Report.appendWarning(SquirrelImporter.Report.mergeFailed(1), paths: paths)
        let warnings = SquirrelImporter.Report.load(paths)?.warnings ?? []
        #expect(warnings.filter { $0.contains("词频快照未能合并") } == [SquirrelImporter.Report.mergeFailed(1)])
    }
}
