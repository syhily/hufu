import Foundation
import Testing
@testable import HufuCore

struct PhraseTableTests {
    let paths: HufuPaths

    init() throws {
        paths = HufuPaths(userDataDir: FileManager.default.temporaryDirectory.appendingPathComponent("hufu-phrases-\(UUID().uuidString)"))
        try FileManager.default.createDirectory(at: paths.stagingDir, withIntermediateDirectories: true)
        try "schema_list:\n  - schema: tigress\n".write(to: paths.builtConfig("default"), atomically: true, encoding: .utf8)
    }

    @Test func usesTheHufuDictionaryTable() {
        let store = SettingsStore(paths: paths)
        let url = store.phraseTableURL(.hufu)
        #expect(url.lastPathComponent == "huma_custom.dict.yaml")
        #expect(PhraseTable.hufu.schemas == ["tigress"])
    }

    @Test func importMergesWithoutDuplicatesAndBacksUp() throws {
        let store = SettingsStore(paths: paths)
        let table = PhraseTable.hufu
        var seed = CustomPhrases(header: CustomPhrases.hufuDictionaryHeader)
        seed.add(.init(text: "虎码", code: "zhmn"))
        try seed.saveDictionary(to: store.phraseTableURL(table))
        let source = paths.userDataDir.appendingPathComponent("incoming.txt")
        try "# Rime table\n虎码\tzhmn\n你好\tjxbh\t9\nbad\thas\ttab\textra\n".write(to: source, atomically: true, encoding: .utf8)
        let result = try store.importPhrases(from: source, into: table)
        #expect(result == PhraseMergeResult(added: 1, skipped: 1))
        let phrases = CustomPhrases.loadDictionary(from: store.phraseTableURL(table))
        #expect(phrases.phrases.map(\.text) == ["虎码", "你好"])
        #expect(phrases.phrases.last?.weight == nil)
        let backups = (try? FileManager.default.contentsOfDirectory(atPath: paths.hufuDir.appendingPathComponent("backup").path)) ?? []
        #expect(backups.contains { $0.hasSuffix("huma_custom.dict.yaml") })
    }

    @Test func dictionaryRoundTripKeepsHeaderAndStem() throws {
        let text = """
        # Rime dictionary
        ---
        name: huma_custom
        version: "1"
        columns: [text, code, weight, stem]
        ...
        虎码\tzhmn\t100\tzh
        你好\tjxbh
        """
        var phrases = CustomPhrases(parsingDictionary: text)
        #expect(phrases.phrases.map(\.text) == ["虎码", "你好"])
        #expect(phrases.phrases[0].stem == "zh")
        #expect(phrases.phrases[1].weight == nil)
        phrases.add(.init(text: "我们", code: "tuja"))
        let output = phrases.serializedDictionary
        #expect(output.hasPrefix("# Rime dictionary\n"))
        #expect(output.contains("我们\ttuja\t\(CustomPhrases.defaultDictionaryWeight)\n"))
        #expect(CustomPhrases(parsingDictionary: output) == phrases)
    }
}
