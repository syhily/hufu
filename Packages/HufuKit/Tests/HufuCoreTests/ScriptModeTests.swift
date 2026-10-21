import Foundation
import Testing
@testable import HufuCore

struct ScriptModeTests {
    /// A stand-in for the shipped tables: 马/发/为/龙 have traditional forms, 龙 is not
    /// itself standard. The array order defines the tiers (all five in tier 1).
    private let filter = ScriptFilter(
        conversions: ["马": ["馬"], "发": ["發", "髮"], "为": ["爲", "為"], "龙": ["龍"], "个": ["個"],
                      "你": ["你", "妳"]],
        common: ["一", "马", "发", "为", "好", "你", "中", "国", "个"]
    )

    /// 7000 characters straight out of the CJK block, so the tier boundaries are real.
    private static let table: [Character] = (0..<7000).map { Character(UnicodeScalar(0x4E00 + $0)!) }

    /// The same table plus two conversions, for the 混打 ordering.
    private let ordered = ScriptFilter(
        conversions: [ScriptModeTests.table[0]: ["馬"], ScriptModeTests.table[3500]: ["龍"]],
        common: ScriptModeTests.table
    )

    // MARK: - Tiers

    @Test func tiersFollowThePublishedOrder() {
        let table = Self.table
        #expect(ordered.tier(of: table[0]) == 1)
        #expect(ordered.tier(of: table[3499]) == 1)   // 一级 last
        #expect(ordered.tier(of: table[3500]) == 2)   // 二级 first
        #expect(ordered.tier(of: table[6499]) == 2)   // 二级 last
        #expect(ordered.tier(of: table[6500]) == 3)   // 三级 first
        #expect(ordered.tier(of: table[6999]) == 3)
        #expect(ordered.tier(of: "馬") == nil)
    }

    // MARK: - 打简出繁: 只打简体's table, read through the conversion

    @Test func tradOutputKeepsTheSimplifiedUniverse() {
        // Converted forms whose source is standard survive, including multi-value rows.
        #expect(filter.keeps("馬", mode: .tradOutput))
        #expect(filter.keeps("發", mode: .tradOutput))
        #expect(filter.keeps("髮", mode: .tradOutput))   // 发 → 發/髮
        #expect(filter.keeps("爲", mode: .tradOutput))
        #expect(filter.keeps("為", mode: .tradOutput))   // 为 → 爲/為
        // Characters that are standard on their own, and non-CJK text, always pass.
        #expect(filter.keeps("好", mode: .tradOutput))
        #expect(filter.keeps("abc馬", mode: .tradOutput))
        // A form whose source is outside the table, and anything the table never heard of.
        #expect(!filter.keeps("龍", mode: .tradOutput))
        #expect(!filter.keeps("龘", mode: .tradOutput))
        // A rare simplified character is outside the universe too.
        #expect(!filter.keeps("氵", mode: .tradOutput))
    }

    @Test func tradOutputDropsCandidatesInOrder() {
        let candidates = ["馬", "龍", "好", "髮", "龘"]
        #expect(filter.order(candidates, mode: .tradOutput) == [0, 2, 3])
    }

    // MARK: - 只打繁体 / 只打简体

    @Test func tradOnlyDropsWhatStillCarriesASimplifiedGlyph() {
        let candidates = ["馬", "马", "马上", "你好", "頭髮"]
        // 马 and 马上 still carry a glyph with a traditional form; 馬/你好/頭髮 are fine.
        #expect(filter.order(candidates, mode: .tradOnly) == [0, 3, 4])
        #expect(filter.keeps("馬", mode: .tradOnly))
        #expect(!filter.keeps("马上", mode: .tradOnly))
    }

    /// A key that lists itself among its outputs (`你 → 你 妳`) is not a simplified-only
    /// character: it stays 你 in traditional text, so 只打繁体 must keep 你好.
    @Test func tradOnlyKeepsSelfPreservingKeys() {
        #expect(!filter.convertible.contains("你"))
        #expect(filter.convertible.contains("马") && filter.convertible.contains("发"))
        #expect(filter.keeps("你好", mode: .tradOnly))
        #expect(filter.keeps("妳好", mode: .tradOnly))    // 妳 is a value, not a key
        #expect(filter.keeps("對", mode: .tradOnly))     // a value, not a key
        #expect(!filter.keeps("马上", mode: .tradOnly))  // 马 → 馬 is a real conversion
        #expect(!filter.keeps("頭髮发", mode: .tradOnly))
        #expect(filter.order(["你好", "马上", "妳好"], mode: .tradOnly) == [0, 2])

        // A row whose only output is itself is not a conversion either.
        let selfOnly = ScriptFilter(conversions: ["教": ["教"], "对": ["對"]], common: ["教", "对"])
        #expect(selfOnly.convertible == ["对"])
        #expect(selfOnly.keeps("教", mode: .tradOnly))
        #expect(!selfOnly.keeps("对", mode: .tradOnly))
    }

    @Test func simpOnlyDropsWhatIsOutsideTheStandardTable() {
        let candidates = ["你好", "你們", "你好嗎", "中国", "馬"]
        // 們/嗎/馬 are not in the stand-in table; 中国 is.
        #expect(filter.order(candidates, mode: .simpOnly) == [0, 3])
    }

    @Test func nonCJKCharactersNeitherHelpNorHurt() {
        let candidates = ["abc", "123", "a马b", "馬!", "（你好）"]
        #expect(filter.order(candidates, mode: .simpOnly) == [0, 1, 2, 4])
        #expect(filter.order(candidates, mode: .tradOnly) == [0, 1, 3, 4])
    }

    /// The dictionary offers CJK radicals as candidates (`⻢` for `nm`); they are not
    /// standard characters, so 只打简体 / 打简出繁 drop them like any other rare glyph.
    @Test func radicalsCountAsCJK() {
        #expect(!filter.keeps("⻢", mode: .simpOnly))
        #expect(!filter.keeps("⻢", mode: .tradOutput))
        #expect(filter.keeps("⻢", mode: .tradOnly))   // no simplified counterpart to drop
        #expect(filter.order(["马", "⻢"], mode: .simpOnly) == [0])
    }

    // MARK: - 繁简混打: tier order, traditional last

    @Test func mixedSortsByTierThenOthersThenTraditional() {
        let candidates = ["馬", "一", "abc", String(Self.table[6500]), String(Self.table[3500]), "龍", "你好"]
        // 馬/龍 are forms (traditional), 一/你好 are tier 1, table[3500] tier 2,
        // table[6500] tier 3, "abc" has no CJK at all.
        #expect(ordered.order(candidates, mode: .mixed) == [1, 6, 4, 3, 2, 0, 5])
    }

    @Test func mixedKeepsTheDictionaryOrderInsideAGroup() {
        let candidates = [String(Self.table[3]), String(Self.table[1]), String(Self.table[2])]
        #expect(ordered.order(candidates, mode: .mixed) == [0, 1, 2])
    }

    @Test func mixedRanksAWordByItsWorstTier() {
        let table = Self.table
        let word = String(table[0]) + String(table[3500])          // tier 1 + tier 2
        let last = String(table[0]) + String(table[6500])          // tier 1 + tier 3
        let traditional = String(table[0]) + "馬"                  // a converted form
        let candidates = [word, last, traditional, String(table[0])]
        // plain tier 1, then the tier-2 word, the tier-3 word, and the traditional one.
        #expect(ordered.order(candidates, mode: .mixed) == [3, 0, 1, 2])
    }

    @Test func mixedLeavesTheOrderAloneWhenNothingIsKnown() {
        let empty = ScriptFilter(conversions: [:], common: [])
        #expect(empty.order(["馬", "abc", "zzz"], mode: .mixed) == [0, 1, 2])
    }

    // MARK: - Mapping back to rime

    @Test func mappingRunsFromDisplayOrderBackToRimeOrder() {
        let candidates = ["馬", "马", "马上", "媽媽", "你好"]
        let order = filter.order(candidates, mode: .tradOnly)
        #expect(order == [0, 3, 4])
        // Display 1 is rime's 3, display 2 rime's 4.
        #expect(order[1] == 3 && order[2] == 4)
        #expect(order.map { candidates[$0] } == ["馬", "媽媽", "你好"])

        // Reordering is a mapping too: display order differs from the page's own order.
        let sorted = ordered.order(["馬", "一", "abc"], mode: .mixed)
        #expect(sorted == [1, 2, 0])
        #expect(sorted.map { ["馬", "一", "abc"][$0] } == ["一", "abc", "馬"])
    }

    @Test func everyCandidateCanBeFilteredOut() {
        #expect(filter.order(["馬", "們"], mode: .simpOnly) == [])
        #expect(filter.order(["马", "个"], mode: .tradOnly) == [])
        #expect(filter.order([], mode: .tradOnly) == [])
    }

    /// A missing table must not hide everything: the rule it backs simply stands down.
    @Test func emptyTablesDisableTheirRule() {
        let empty = ScriptFilter(conversions: [:], common: [])
        #expect(empty.order(["马", "馬", "你好"], mode: .tradOnly) == [0, 1, 2])
        #expect(empty.order(["马", "馬", "你好"], mode: .simpOnly) == [0, 1, 2])
        #expect(empty.order(["马", "馬", "你好"], mode: .tradOutput) == [0, 1, 2])
        #expect(empty.order(["abc"], mode: .simpOnly) == [0])
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

    // MARK: - Shipped tables

    @Test func loadsTheShippedTables() throws {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let filter = ScriptFilter.load(sharedDataDir: repo.appendingPathComponent("SharedSupport"))
        #expect(filter.conversions.count == 4449)   // every STCharacters_Tu.txt row
        // 672 rows list the key itself as an output (你 → 你/妳, 万 → 萬/万): they are
        // ordinary text, not simplified-only characters.
        #expect(filter.convertible.count == 3777)
        #expect(filter.common.count == 8105)        // 《通用规范汉字表》
        // Multi-value rows keep every form.
        #expect(filter.conversions["为"]?.map(String.init) == ["爲", "為"])
        #expect(filter.conversions["发"]?.map(String.init) == ["發", "髮"])
        #expect(filter.convertible.contains("马"))
        #expect(filter.convertible.contains("对"))
        #expect(!filter.convertible.contains("馬"))
        #expect(!filter.convertible.contains("你"))    // 你 → 你 妳
        #expect(!filter.convertible.contains("教"))    // 教 → 教

        // 一级 / 二级 / 三级 by position in the published table.
        #expect(filter.tier(of: "一") == 1)
        #expect(filter.tier(of: "矗") == 1)
        #expect(filter.tier(of: "乂") == 2)
        #expect(filter.tier(of: "齉") == 2)
        #expect(filter.tier(of: "亍") == 3)
        #expect(filter.tier(of: "馬") == nil)

        // 打简出繁: 對/爲 are kept because 对/为 are standard; 龘 is out (its source 𮹝 is not).
        for text in ["對", "爲", "為", "發", "髮", "你好"] {
            #expect(filter.keeps(text, mode: .tradOutput), "\(text)")
        }
        #expect(!filter.keeps("龘", mode: .tradOutput))
        #expect(filter.order(["對", "龘", "你好"], mode: .tradOutput) == [0, 2])

        // 只打繁体 drops 马上 (still simplified), keeps the converted forms and 你好
        // (你 → 你/妳 lists 你 itself, so it is ordinary text).
        #expect(filter.order(["馬上", "马上", "馬"], mode: .tradOnly) == [0, 2])
        #expect(!filter.convertible.contains("你"))
        #expect(filter.keeps("你好", mode: .tradOnly))
        #expect(filter.order(["你好", "您好"], mode: .tradOnly) == [0, 1])
        // 只打简体 keeps 马/你好 and drops the traditional forms.
        #expect(filter.order(["你好", "妳好", "馬"], mode: .simpOnly) == [0])

        // 混打: standard tier 1 first, then anything else, traditional forms last.
        #expect(filter.order(["馬", "马", "你好", "對", "abc"], mode: .mixed) == [1, 2, 4, 0, 3])
    }

    @Test func missingSharedDirectoryYieldsEmptyTables() {
        let filter = ScriptFilter.load(sharedDataDir: nil)
        #expect(filter.convertible.isEmpty && filter.common.isEmpty)
        #expect(filter.order(["马", "馬"], mode: .simpOnly) == [0, 1])
        #expect(filter.order(["马", "馬"], mode: .mixed) == [0, 1])
    }
}
