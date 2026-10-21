import Foundation
import Testing
@testable import HufuCore

struct ScriptModeTests {
    /// A stand-in for the shipped tables: 马/个/后/发 have traditional forms; only the
    /// second set is inside 《通用规范汉字表》.
    private let filter = ScriptFilter(
        convertible: ["马", "个", "后", "发"],
        common: ["马", "个", "你", "好", "中", "国"]
    )

    @Test func modesWithoutAFilterKeepEveryCandidateInOrder() {
        let candidates = ["馬", "马", "你好"]
        #expect(filter.keep(candidates, mode: .mixed) == [0, 1, 2])
        #expect(filter.keep(candidates, mode: .tradOutput) == [0, 1, 2])
        #expect(filter.keep([], mode: .tradOnly) == [])
        #expect(filter.keep([], mode: .simpOnly) == [])
    }

    @Test func tradOnlyDropsWhatStillCarriesASimplifiedGlyph() {
        let candidates = ["馬", "马", "马上", "你好", "頭髮"]
        // 马 and 马上 still carry a glyph with a traditional form; 馬/你好/頭髮 are fine.
        #expect(filter.keep(candidates, mode: .tradOnly) == [0, 3, 4])
        #expect(filter.keeps("馬", mode: .tradOnly))
        #expect(!filter.keeps("马上", mode: .tradOnly))
    }

    @Test func simpOnlyDropsWhatIsOutsideTheStandardTable() {
        let candidates = ["你好", "你們", "你好嗎", "中国", "馬"]
        // 們/嗎/馬 are not in the 8105 stand-in; 中国 is.
        #expect(filter.keep(candidates, mode: .simpOnly) == [0, 3])
    }

    @Test func nonCJKCharactersNeitherHelpNorHurt() {
        let candidates = ["abc", "123", "a马b", "馬!", "（你好）"]
        #expect(filter.keep(candidates, mode: .simpOnly) == [0, 1, 2, 4])
        #expect(filter.keep(candidates, mode: .tradOnly) == [0, 1, 3, 4])
    }

    @Test func mappingRunsFromDisplayOrderBackToRimeOrder() {
        let candidates = ["馬", "马", "马上", "媽媽", "你好"]
        let kept = filter.keep(candidates, mode: .tradOnly)
        #expect(kept == [0, 3, 4])
        // The panel shows three items; display 1 is rime's 3, display 2 rime's 4.
        #expect(kept[1] == 3 && kept[2] == 4)
        #expect(kept.map { candidates[$0] } == ["馬", "媽媽", "你好"])
    }

    @Test func everyCandidateCanBeFilteredOut() {
        #expect(filter.keep(["馬", "們"], mode: .simpOnly) == [])
        #expect(filter.keep(["马", "个"], mode: .tradOnly) == [])
    }

    /// A missing table must not hide everything: the rule it backs simply stands down.
    @Test func emptyTablesDisableTheirRule() {
        let empty = ScriptFilter(convertible: [], common: [])
        #expect(empty.keep(["马", "馬", "你好"], mode: .tradOnly) == [0, 1, 2])
        #expect(empty.keep(["马", "馬", "你好"], mode: .simpOnly) == [0, 1, 2])
        #expect(empty.keep(["abc"], mode: .simpOnly) == [0])
    }

    @Test func sessionOptionResolvesTheModeInForce() {
        // ⌃O / ⌃⇧4 flip librime's option for the session.
        #expect(ScriptMode.mixed.resolved(traditional: false) == .mixed)
        #expect(ScriptMode.mixed.resolved(traditional: true) == .tradOutput)
        #expect(ScriptMode.tradOutput.resolved(traditional: true) == .tradOutput)
        #expect(ScriptMode.tradOutput.resolved(traditional: false) == .mixed)
        #expect(ScriptMode.tradOnly.resolved(traditional: true) == .tradOnly)
        #expect(ScriptMode.tradOnly.resolved(traditional: false) == .simpOnly)
        #expect(ScriptMode.simpOnly.resolved(traditional: false) == .simpOnly)
        #expect(ScriptMode.simpOnly.resolved(traditional: true) == .tradOnly)

        #expect(ScriptMode.tradOutput.usesTraditionalConversion && ScriptMode.tradOnly.usesTraditionalConversion)
        #expect(!ScriptMode.mixed.usesTraditionalConversion && !ScriptMode.simpOnly.usesTraditionalConversion)
        #expect(ScriptMode.tradOnly.filters && ScriptMode.simpOnly.filters)
        #expect(!ScriptMode.mixed.filters && !ScriptMode.tradOutput.filters)
    }

    @Test func loadsTheShippedTables() throws {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let filter = ScriptFilter.load(sharedDataDir: repo.appendingPathComponent("SharedSupport"))
        #expect(filter.convertible.count == 4449)   // STCharacters_Tu.txt keys
        #expect(filter.common.count == 8105)        // 《通用规范汉字表》
        #expect(filter.convertible.contains("马"))
        #expect(filter.convertible.contains("个"))
        #expect(!filter.convertible.contains("馬"))
        #expect(filter.common.contains("好"))
        #expect(!filter.common.contains("馬"))

        // Real dictionary output: 马上 converts to 馬上, which 只打繁体 keeps.
        #expect(filter.keep(["馬上", "马 上", "馬上"], mode: .tradOnly) == [0, 2])
        #expect(filter.keep(["你好", "妳好"], mode: .simpOnly) == [0])
    }

    @Test func missingSharedDirectoryYieldsEmptyTables() {
        let filter = ScriptFilter.load(sharedDataDir: nil)
        #expect(filter.convertible.isEmpty && filter.common.isEmpty)
        #expect(filter.keep(["马", "馬"], mode: .simpOnly) == [0, 1])
    }
}
