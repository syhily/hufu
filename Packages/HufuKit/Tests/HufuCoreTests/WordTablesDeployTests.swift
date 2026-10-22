import Foundation
import Testing
import RimeKit
@testable import HufuCore

/// 词汇输入 against the real tigress build: each mount decides which word table the
/// engine consults. Needs `bash scripts/stage-huma.sh` (the app's bundled data).
@MainActor
@Suite(.serialized)
struct WordTablesDeployTests {
    static let shared = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("build/SharedSupport")

    let root: URL
    let paths: HufuPaths
    let layers: ConfigLayers
    let engine = RimeEngine.shared

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("hufu-words-deploy-\(UUID().uuidString)")
        paths = HufuPaths(userDataDir: root, sharedDataDir: Self.shared)
        layers = ConfigLayers(paths: paths)
        try FileManager.default.createDirectory(at: paths.userDataDir, withIntermediateDirectories: true)
        try #require(FileManager.default.fileExists(atPath: Self.shared.appendingPathComponent("tigress.schema.yaml").path),
                     "run scripts/stage-huma.sh before the tests")
        engine.initialize(RimeTraits(
            sharedDataDir: Self.shared, userDataDir: paths.userDataDir,
            prebuiltDataDir: Self.shared.appendingPathComponent("build"), minLogLevel: 2))
    }

    private func finish() {
        engine.finalize()
        try? FileManager.default.removeItem(at: root)
    }

    /// Mounts one combination, deploys it, and types `keys` in a fresh session.
    private func candidates(_ keys: String, enabled: Bool, mode: ScriptMode) throws -> [String] {
        try layers.updateGenerated(.schema("tigress")) { patch in
            patch.removeAll { entry in WordTables.Table.allCases.contains { $0.keypath == entry.key } }
            for (keypath, tag) in WordTables.tags(enabled: enabled, mode: mode) {
                patch.append(.init(keypath, .string(tag)))
            }
        }
        try layers.prepareForDeploy(extraTargets: [.schema("tigress")])
        engine.deployAndWait()
        let session = try engine.createSession()
        #expect(session.selectSchema("tigress"))
        #expect(session.simulate(keySequence: keys))
        return session.context().candidates.map(\.text)
    }

    @Test func wordsOffLeavesOnlySingleCharacters() throws {
        defer { finish() }
        // tuja is the code of 我们, which only the word table carries.
        #expect(try candidates("tuja", enabled: false, mode: .mixed).isEmpty)
    }

    @Test func mixedMountsSimplifiedWords() throws {
        defer { finish() }
        let texts = try candidates("tuja", enabled: true, mode: .mixed)
        #expect(texts.contains("我们"))
    }

    @Test func tradOutputMountsConvertedWords() throws {
        defer { finish() }
        // words_trad is keyed by the simplified code and holds the converted word.
        let texts = try candidates("tuja", enabled: true, mode: .tradOutput)
        #expect(texts.contains("我們"))
        #expect(!texts.contains("我们"))
    }

    @Test func tradOnlyMountsTraditionalCodes() throws {
        defer { finish() }
        // 國家 keeps its own (traditional) code rpwj in tigress_words_tradown.
        let texts = try candidates("rpwj", enabled: true, mode: .tradOnly)
        #expect(texts.contains("國家"))
        #expect(!texts.contains("国家"))
    }

    @Test func simpOnlyMountsSimplifiedWordsAndLeavesTheFilterInCharge() throws {
        defer { finish() }
        let texts = try candidates("cdii", enabled: true, mode: .simpOnly)
        #expect(texts.contains("屌丝"))
        // 屌 is outside 《通用规范汉字表》, so the frontend filter is what drops the word.
        let filter = ScriptFilter.load(sharedDataDir: Self.shared)
        #expect(!filter.order(texts, mode: .simpOnly).map { texts[$0] }.contains("屌丝"))
    }
}
