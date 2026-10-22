import Foundation
import Testing
@testable import HufuCore

struct SpecialInputTests {
    /// A fixed clock in a fixed zone, so the formats never depend on when the test runs.
    private func context(_ stamp: String, zone: String = "Asia/Shanghai") -> SpecialInput.Context {
        let timeZone = TimeZone(identifier: zone) ?? .gmt
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = stamp.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        let now = calendar.date(from: DateComponents(
            year: parts[0], month: parts[1], day: parts[2],
            hour: parts[3], minute: parts[4], second: parts[5]))
        return SpecialInput.Context(now: now ?? Date(timeIntervalSince1970: 0), timeZone: timeZone)
    }

    private func texts(_ input: String, _ context: SpecialInput.Context? = nil) -> [String]? {
        SpecialInput.candidates(for: input, context: context ?? self.context("2026-10-22 23:05:36"))
            .map { $0.map(\.text) }
    }

    private func comments(_ input: String, _ context: SpecialInput.Context) -> [String] {
        (SpecialInput.candidates(for: input, context: context) ?? []).map(\.comment)
    }

    // MARK: - Calculator

    @Test func calculatorEvaluatesArithmetic() {
        #expect(texts("=1+2*3") == ["1+2*3=7"])
        #expect(texts("=(1+2)/4") == ["(1+2)/4=0.75"])
        #expect(texts("=-5+2") == ["-5+2=-3"])
        #expect(texts("=2^10") == ["2^10=1024"])
        #expect(texts("=2**10") == ["2**10=1024"])
        #expect(texts("=0.1+0.2") == ["0.1+0.2=0.3"])
        #expect(texts("= 1 + 2 ") == ["1+2=3"])
    }

    @Test func calculatorRemainderAndPercent() {
        #expect(texts("=10%3") == ["10%3=1"])
        #expect(texts("=-10%3") == ["-10%3=2"])   // Lua's floor-mod
        #expect(texts("=10%") == ["10%=0.1"])     // a trailing % reads as percent
        #expect(texts("=(10+5)%4") == ["(10+5)%4=3"])
    }

    @Test func calculatorRejectsWhatItCannotEvaluate() {
        #expect(texts("=") == nil)
        #expect(texts("=1+") == nil)
        #expect(texts("=(1+2") == nil)
        #expect(texts("=abc") == nil)
        #expect(texts("=1/0") == nil)   // division by zero never reaches the panel
        #expect(texts("=0/0") == nil)
        #expect(texts("=1..2") == nil)
        #expect(texts("=1+2)") == nil)
    }

    // MARK: - Chinese numerals

    /// Expected values are number.lua's own output (run against Lua 5.5 with the file
    /// from the Tiger-Code scheme data at upstream commit 76226af).
    @Test func numeralsMatchTheLuaTranslator() {
        let samples: [String: [String]] = [
            "1": ["一", "壹", "壹元整", "一元整"],
            "10": ["一十", "壹拾", "壹拾元整", "一十元整"],
            "11": ["一十一", "壹拾壹", "壹拾壹元整", "一十一元整"],
            "101": ["一百〇一", "壹佰零壹", "壹佰零壹元整", "一百〇一元整"],
            "1001": ["一千〇一", "壹仟零壹", "壹仟零壹元整", "一千〇一元整"],
            "10000": ["一万", "壹萬", "壹万元整", "一万元整"],
            "10001": ["一万〇一", "壹萬零壹", "壹万零壹元整", "一万〇一元整"],
            "10010": ["一万〇一十", "壹萬零壹拾", "壹万零壹拾元整", "一万〇一十元整"],
            "10100": ["一万〇一百", "壹萬零壹佰", "壹万零壹佰元整", "一万〇一百元整"],
            "100000": ["十万", "拾萬", "拾万元整", "十万元整"],
            "12345678": ["一千二百三十四万五千六百七十八", "壹仟贰佰叁拾肆萬伍仟陆佰柒拾捌",
                         "壹仟贰佰叁拾肆万伍仟陆佰柒拾捌元整", "一千二百三十四万五千六百七十八元整"],
            "123456789": ["一亿二千三百四十五万六千七百八十九", "壹億贰仟叁佰肆拾伍萬陆仟柒佰捌拾玖",
                          "壹亿贰仟叁佰肆拾伍万陆仟柒佰捌拾玖元整", "一亿二千三百四十五万六千七百八十九元整"],
            "100000000000": ["一千亿", "壹仟億", "壹仟亿元整", "一千亿元整"],
            "1234.56": ["一千二百三十四点五六", "壹仟贰佰叁拾肆点伍陆",
                        "壹仟贰佰叁拾肆元伍角陆分", "一千二百三十四元五角六分"],
            "1.50": ["一点五〇", "壹点伍零", "壹元伍角", "一元五角"],
            "10.05": ["一十点〇五", "壹拾点零伍", "壹拾元零伍分", "一十元〇五分"],
            "1.001": ["一点〇一", "壹点零壹", "壹元零壹厘", "一元〇一厘"],
            "1.0001": ["一点〇一", "壹点零壹", "壹元零壹毫", "一元〇一毫"],
            "1.00001": ["一点〇一", "壹点零壹", "壹元整", "一元整"],
            "999999999999": ["九千九百九十九亿九千九百九十九万九千九百九十九",
                             "玖仟玖佰玖拾玖億玖仟玖佰玖拾玖萬玖仟玖佰玖拾玖",
                             "玖仟玖佰玖拾玖亿玖仟玖佰玖拾玖万玖仟玖佰玖拾玖元整",
                             "九千九百九十九亿九千九百九十九万九千九百九十九元整"],
        ]
        for (input, expected) in samples {
            #expect(texts("/" + input) == expected, "\(input)")
        }
    }

    /// The only place the port improves on number.lua: zero used to read 数值超限！.
    @Test func numeralsReadZeroAsZero() {
        #expect(texts("/0") == ["〇", "零", "零元整", "〇元整"])
        #expect(texts("/0.5") == ["〇点五", "零点伍", "零元伍角", "〇元五角"])
        #expect(texts("/000123") == ["一百二十三", "壹佰贰拾叁", "壹佰贰拾叁元整", "一百二十三元整"])
    }

    @Test func numeralsRejectOverflowAndNonNumbers() {
        #expect(texts("/1000000000000") == nil)   // 13 digits: number.lua gives up
        #expect(texts("/12a") == nil)
        #expect(texts("/1.2.3") == nil)
        #expect(texts("/.5") == nil)
    }

    // MARK: - Date and time

    @Test func dateMatchesTheLuaFormats() {
        let fixed = context("2026-10-22 23:05:36")
        #expect(texts("/date", fixed) == [
            "2026.10.22", "2026-10-22", "2026年10月22日", "Oct 22, 2026",
            "10/22/2026", "二〇二六年十月二十二日", "20261022",
        ])
        #expect(comments("/date", fixed) == Array(repeating: "295/365", count: 7))
    }

    @Test func dateDropsPaddingAndCountsLeapYears() {
        let single = context("2026-01-05 09:05:07")
        #expect(texts("/date", single) == [
            "2026.01.05", "2026-01-05", "2026年01月05日", "Jan 5, 2026",
            "1/5/2026", "二〇二六年一月五日", "20260105",
        ])
        #expect(comments("/date", single) == Array(repeating: "005/365", count: 7))

        let leap = context("2024-02-29 08:00:00")
        #expect(texts("/date", leap)?.first == "2024.02.29")
        #expect(comments("/date", leap) == Array(repeating: "060/366", count: 7))
    }

    @Test func timeMatchesTheLuaFormats() {
        let fixed = context("2026-10-22 23:05:36")
        #expect(texts("/time", fixed) == ["23:05", "下午11:05", "23:05:36", "23点05分36秒"])
        #expect(comments("/time", fixed) == Array(repeating: "子时(夜半｜三更)", count: 4))

        let morning = context("2024-02-29 08:00:00")
        #expect(texts("/time", morning) == ["08:00", "上午08:00", "08:00:00", "8点00分00秒"])
        #expect(comments("/time", morning) == Array(repeating: "辰时(食时)", count: 4))

        let noon = context("2026-10-22 12:00:00")
        #expect(texts("/time", noon)?.prefix(2) == ["12:00", "下午12:00"])

        let midnight = context("2026-10-22 00:30:00")
        #expect(texts("/time", midnight)?.prefix(2) == ["00:30", "上午12:30"])
    }

    @Test func weekMatchesTheLuaFormats() {
        let fixed = context("2026-10-22 23:05:36")
        #expect(texts("/week", fixed) == ["周四", "星期四", "Thu", "Thursday"])
        #expect(comments("/week", fixed) == Array(repeating: "第42周", count: 4))

        // Days before the first Monday are week 0, as C's %W counts them.
        let january = context("2026-01-05 09:05:07")
        #expect(texts("/week", january) == ["周一", "星期一", "Mon", "Monday"])
        #expect(comments("/week", january) == Array(repeating: "第01周", count: 4))
    }

    @Test func lunarDateUsesTheChineseCalendar() {
        #expect(texts("/cdate", context("2026-10-22 23:05:36")) == [
            "农历九月十三", "丙午年(马)九月十三", "丙午年(马)九月十三子时(夜半｜三更)",
        ])
        #expect(texts("/cdate", context("2024-02-10 00:30:00"))?.first == "农历正月初一")
        #expect(texts("/cdate", context("2024-02-10 00:30:00"))?[1] == "甲辰年(龙)正月初一")
        // 2023 had a leap second month: 闰二月.
        #expect(texts("/cdate", context("2023-04-01 12:00:00")) == [
            "农历闰二月十一", "癸卯年(兔)闰二月十一", "癸卯年(兔)闰二月十一午时(日中)",
        ])
    }

    // MARK: - Triggers

    @Test func homophonesReachTheSameCandidates() {
        let fixed = context("2026-10-22 23:05:36")
        for alias in ["/fsj", "/fuj", "/okao"] {
            #expect(texts(alias, fixed) == texts("/time", fixed), "\(alias)")
        }
        for alias in ["/frq", "/orzh"] {
            #expect(texts(alias, fixed) == texts("/date", fixed), "\(alias)")
        }
        for alias in ["/fxq", "/olzh"] {
            #expect(texts(alias, fixed) == texts("/week", fixed), "\(alias)")
        }
        for alias in ["/fnl", "/wtxs"] {
            #expect(texts(alias, fixed) == texts("/cdate", fixed), "\(alias)")
        }
    }

    @Test func ordinaryInputIsLeftToLibrime() {
        for input in ["", "j", "jxbh", "/", "/baidu", "/huma", "/fjq", "/djs", "/L", "/time ", "time"] {
            #expect(texts(input) == nil, "\(input)")
        }
    }

    /// Settings › 输入习惯 › 便利功能: a switch that is off yields no candidates at all,
    /// and leaves the other two alone.
    @Test func switchesTurnEachFamilyOff() {
        let fixed = context("2026-10-22 23:05:36")
        let clockOnly = SpecialInput.Options(dateTime: true, calculator: true, numerals: true)
        #expect(SpecialInput.candidates(for: "/time", context: fixed, options: clockOnly) != nil)

        let withoutDateTime = SpecialInput.Options(dateTime: false, calculator: true, numerals: true)
        for input in ["/time", "/date", "/week", "/cdate", "/fsj", "/orzh", "/olzh", "/wtxs"] {
            #expect(SpecialInput.candidates(for: input, context: fixed, options: withoutDateTime) == nil, "\(input)")
        }
        #expect(SpecialInput.candidates(for: "=1+2", options: withoutDateTime) != nil)
        #expect(SpecialInput.candidates(for: "/1234.56", options: withoutDateTime) != nil)

        let withoutCalculator = SpecialInput.Options(dateTime: true, calculator: false, numerals: true)
        #expect(SpecialInput.candidates(for: "=1+2", options: withoutCalculator) == nil)
        #expect(SpecialInput.candidates(for: "/1234.56", options: withoutCalculator) != nil)
        #expect(SpecialInput.candidates(for: "/time", context: fixed, options: withoutCalculator) != nil)

        let withoutNumerals = SpecialInput.Options(dateTime: true, calculator: true, numerals: false)
        #expect(SpecialInput.candidates(for: "/1234.56", options: withoutNumerals) == nil)
        #expect(SpecialInput.candidates(for: "/0", options: withoutNumerals) == nil)
        #expect(SpecialInput.candidates(for: "=1+2", options: withoutNumerals) != nil)
        #expect(SpecialInput.candidates(for: "/time", context: fixed, options: withoutNumerals) != nil)

        let allOff = SpecialInput.Options(dateTime: false, calculator: false, numerals: false)
        for input in ["/time", "/date", "/week", "/cdate", "/1234.56", "=1+2"] {
            #expect(SpecialInput.candidates(for: input, context: fixed, options: allOff) == nil, "\(input)")
        }
        // Keys fall through to the engine when nothing is injected.
        #expect(SpecialInput.action(for: "1", input: "/time", pageCount: 1, options: allOff) == .select(0))
    }

    /// What a key does while the frontend's page is up (the controller only dispatches).
    @Test func keysSelectPageOrGrowTheInput() {
        // /time: digits cannot extend it, so they select.
        #expect(SpecialInput.action(for: "1", input: "/time", pageCount: 1) == .select(0))
        #expect(SpecialInput.action(for: "4", input: "/time", pageCount: 1) == .select(3))
        #expect(SpecialInput.action(for: ";", input: "/time", pageCount: 1) == .select(1))
        #expect(SpecialInput.action(for: "'", input: "/time", pageCount: 1) == .select(2))
        #expect(SpecialInput.action(for: " ", input: "/time", pageCount: 1) == .select(0))
        #expect(SpecialInput.action(for: "\r", input: "/time", pageCount: 1) == .select(0))

        // A digit that would grow a number or an expression goes back to librime.
        #expect(SpecialInput.action(for: "2", input: "/1", pageCount: 1) == nil)
        #expect(SpecialInput.action(for: "3", input: "=1+2", pageCount: 1) == nil)
        #expect(SpecialInput.action(for: "0", input: "/1", pageCount: 1) == nil)

        // Paging only when there is another page.
        #expect(SpecialInput.action(for: "=", input: "/date", pageCount: 2) == .page(backward: false))
        #expect(SpecialInput.action(for: "-", input: "/date", pageCount: 2) == .page(backward: true))
        #expect(SpecialInput.action(for: "=", input: "/time", pageCount: 1) == nil)

        // Everything else stays with the engine: ⌫ edits, Esc clears, letters refine.
        for key: Character in ["\u{7f}", "\u{1b}", "a", "/", "#"] {
            #expect(SpecialInput.action(for: key, input: "/time", pageCount: 2) == nil, "\(key)")
        }
    }

    @Test func timeZoneMovesTheClock() {
        // One instant, seen from two zones: 02:00 in Shanghai is still the evening before in UTC.
        let now = context("2026-10-23 02:00:00").now
        let shanghai = SpecialInput.Context(now: now, timeZone: TimeZone(identifier: "Asia/Shanghai") ?? .gmt)
        let utc = SpecialInput.Context(now: now, timeZone: TimeZone(identifier: "UTC") ?? .gmt)
        #expect(texts("/time", shanghai)?.first == "02:00")
        #expect(texts("/time", utc)?.first == "18:00")
        #expect(texts("/date", shanghai)?.first == "2026.10.23")
        #expect(texts("/date", utc)?.first == "2026.10.22")
        #expect(texts("/cdate", shanghai)?.first == "农历九月十四")
        #expect(texts("/cdate", utc)?.first == "农历九月十三")
    }
}
