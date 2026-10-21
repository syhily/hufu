public import Foundation

/// The convenience inputs that the removed librime-lua plugins used to translate:
/// `=1+2` (calculator), `/1234.56` (Chinese numerals), `/time`, `/date`, `/week` and
/// `/cdate`, plus 虎码's homophone spellings of those words.
///
/// Pure functions: the input method swaps librime's candidate page for the returned
/// list and commits the picked text itself. Everything the formats read from the
/// clock is injected through `Context`, so tests pin the date, zone and calendar.
public enum SpecialInput {
    public struct Candidate: Sendable, Equatable, Hashable {
        public var text: String
        public var comment: String

        public init(text: String, comment: String = "") {
            self.text = text
            self.comment = comment
        }
    }

    public struct Context: Sendable {
        public var now: Date
        public var timeZone: TimeZone

        public init(now: Date = Date(), timeZone: TimeZone = .current) {
            self.now = now
            self.timeZone = timeZone
        }
    }

    /// Which convenience inputs are on (Settings › 输入习惯 › 便利功能). Everything is
    /// on by default, which is how Hufu shipped before the switches existed.
    public struct Options: Sendable, Equatable {
        public var dateTime: Bool
        public var calculator: Bool
        public var numerals: Bool

        public init(dateTime: Bool = true, calculator: Bool = true, numerals: Bool = true) {
            self.dateTime = dateTime
            self.calculator = calculator
            self.numerals = numerals
        }
    }

    /// All candidates for a special input, in the order the lua version yielded them,
    /// or nil when the input is not special, its switch is off, or it cannot produce
    /// anything.
    public static func candidates(for input: String, context: Context = Context(),
                                  options: Options = Options()) -> [Candidate]? {
        guard let first = input.first, first == "/" || first == "=" else { return nil }
        if first == "=" { return options.calculator ? calculator(String(input.dropFirst())) : nil }
        let body = String(input.dropFirst())
        if body.first?.isNumber == true { return options.numerals ? numerals(body) : nil }
        guard options.dateTime else { return nil }
        switch body {
        case "time", "fsj", "fuj", "okao":
            return clock(context)
        case "date", "frq", "orzh":
            return date(context)
        case "week", "fxq", "olzh":
            return weekday(context)
        case "cdate", "fnl", "wtxs":
            return lunar(context)
        default:
            return nil
        }
    }

    /// What a single typed character does while a frontend candidate page is shown.
    /// `nil` hands the key to librime — a digit that would grow the input into another
    /// valid form (`/12` after `/1`, `=1+23` after `=1+2`) must reach the engine, or
    /// typing the number would select its first candidate before the second digit.
    public enum Action: Sendable, Equatable {
        /// 0-based position on the visible page.
        case select(Int)
        case page(backward: Bool)
    }

    public static func action(for character: Character, input: String, pageCount: Int,
                              options: Options = Options()) -> Action? {
        switch character {
        case "1"..."9":
            if candidates(for: input + String(character), options: options) != nil { return nil }
            return .select((character.wholeNumberValue ?? 1) - 1)
        case ";":
            return .select(1) // the schema's 次选
        case "'":
            return .select(2) // 三选
        case " ", "\r", "\n":
            return .select(0)
        case "-":
            return pageCount > 1 ? .page(backward: true) : nil
        case "=":
            return pageCount > 1 ? .page(backward: false) : nil
        default:
            return nil
        }
    }

    // MARK: - Calculator (=1+2*3)

    /// `=1+2*3` → `1+2*3=7`. Arithmetic is evaluated by a small recursive-descent parser
    /// over Double — no `NSExpression`, which raises an uncatchable NSException on
    /// malformed input (the IME process would die on a stray `=1+`), silently does
    /// integer division on integer literals, and cannot parse `%` at all.
    private static func calculator(_ expression: String) -> [Candidate]? {
        let text = expression.filter { !$0.isWhitespace }
        guard !text.isEmpty, let value = Expression(text).value(), value.isFinite else { return nil }
        return [Candidate(text: "\(text)=\(plainNumber(value))")]
    }

    /// Lua's `%.14g`: `3` rather than `3.0`, and `0.1+0.2` printing as `0.3`.
    private static func plainNumber(_ value: Double) -> String {
        String(format: "%.14g", value)
    }

    private struct Expression {
        private let characters: [Character]
        private var index = 0

        init(_ text: String) { characters = Array(text) }

        func value() -> Double? {
            var parser = self
            guard let result = parser.sum(), parser.index == parser.characters.count else { return nil }
            return result
        }

        private func peek(_ offset: Int = 0) -> Character? {
            let position = index + offset
            return position < characters.count ? characters[position] : nil
        }

        private mutating func sum() -> Double? {
            guard var value = product() else { return nil }
            while let operation = peek(), operation == "+" || operation == "-" {
                index += 1
                guard let right = product() else { return nil }
                value = operation == "+" ? value + right : value - right
            }
            return value
        }

        private mutating func product() -> Double? {
            guard var value = unary() else { return nil }
            loop: while let operation = peek() {
                switch operation {
                case "*" where peek(1) == "*":
                    break loop
                case "*", "/":
                    index += 1
                    guard let right = unary() else { return nil }
                    value = operation == "*" ? value * right : value / right
                case "%":
                    index += 1
                    if startsOperand {
                        guard let right = unary() else { return nil }
                        value = value - (value / right).rounded(.down) * right // Lua's floor-mod
                    } else {
                        value /= 100 // a trailing `%` reads as "percent": =10% → 0.1
                    }
                default:
                    break loop
                }
            }
            return value
        }

        private var startsOperand: Bool {
            guard let next = peek() else { return false }
            return next.isNumber || next == "." || next == "(" || next == "-" || next == "+"
        }

        private mutating func unary() -> Double? {
            if peek() == "-" {
                index += 1
                return unary().map(-)
            }
            if peek() == "+" {
                index += 1
                return unary()
            }
            return power()
        }

        private mutating func power() -> Double? {
            guard let base = primary() else { return nil }
            if peek() == "^" {
                index += 1
                guard let exponent = unary() else { return nil }
                return pow(base, exponent)
            }
            if peek() == "*", peek(1) == "*" {
                index += 2
                guard let exponent = unary() else { return nil }
                return pow(base, exponent)
            }
            return base
        }

        private mutating func primary() -> Double? {
            if peek() == "(" {
                index += 1
                guard let value = sum(), peek() == ")" else { return nil }
                index += 1
                return value
            }
            var literal = ""
            while let next = peek(), next.isNumber || next == "." {
                literal.append(next)
                index += 1
            }
            guard !literal.isEmpty, literal.filter({ $0 == "." }).count <= 1 else { return nil }
            return Double(literal)
        }
    }

    // MARK: - Chinese numerals (/1234.56, number.lua)

    private static let upperDigits = ["零", "壹", "贰", "叁", "肆", "伍", "陆", "柒", "捌", "玖"]
    private static let lowerDigits = ["〇", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
    private static let upperUnits = ["", "拾", "佰", "仟"]
    private static let lowerUnits = ["", "十", "百", "千"]

    /// The four candidates of number.lua's `number_translatorFunc`, in its order:
    /// digit-by-digit (简/繁), then 元角分 (大写/小写).
    private static func numerals(_ body: String) -> [Candidate]? {
        let parts = body.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2,
              !parts[0].isEmpty,
              parts[0].allSatisfy({ $0.isASCII && $0.isNumber }),
              parts.count == 1 || parts[1].allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }

        let stripped = parts[0].drop { $0 == "0" }
        let whole = stripped.isEmpty ? "0" : String(stripped)
        guard whole.count <= 12 else { return nil } // number.lua: 数值超限
        let fraction = parts.count == 2 ? String(parts[1]) : ""

        if parts.count == 2 {
            return [
                Candidate(text: integer(whole, uppercase: false, groups: ("万", "亿"),
                                        zero: "〇", one: "一", ten: "十", suffix: "点")
                    + digits(fraction, uppercase: false)),
                Candidate(text: integer(whole, uppercase: true, groups: ("萬", "億"),
                                        zero: "〇", one: "一", ten: "十", suffix: "点")
                    + digits(fraction, uppercase: true)),
                Candidate(text: integer(whole, uppercase: true, groups: ("万", "亿"),
                                        zero: "零", one: "壹", ten: "拾", suffix: "元")
                    + fractionUnits(fraction, uppercase: true)),
                Candidate(text: integer(whole, uppercase: false, groups: ("万", "亿"),
                                        zero: "〇", one: "一", ten: "十", suffix: "元")
                    + fractionUnits(fraction, uppercase: false)),
            ]
        }
        return [
            Candidate(text: integer(whole, uppercase: false, groups: ("万", "亿"),
                                    zero: "〇", one: "一", ten: "十", suffix: "")),
            Candidate(text: integer(whole, uppercase: true, groups: ("萬", "億"),
                                    zero: "零", one: "壹", ten: "拾", suffix: "")),
            Candidate(text: integer(whole, uppercase: true, groups: ("万", "亿"),
                                    zero: "零", one: "壹", ten: "拾", suffix: "元")
                + fractionUnits("", uppercase: true)),
            Candidate(text: integer(whole, uppercase: false, groups: ("万", "亿"),
                                    zero: "〇", one: "一", ten: "十", suffix: "元")
                + fractionUnits("", uppercase: false)),
        ]
    }

    /// number.lua's `number2cnChar`: the integer part grouped by 万 / 亿. `uppercase`
    /// picks the digit and unit set (as the lua `flag` does); `zero` / `one` / `ten` are
    /// the figures used to clean the joined groups up; `suffix` is 元, 点 or nothing.
    private static func integer(_ value: String, uppercase: Bool, groups: (String, String),
                                zero: String, one: String, ten: String, suffix: String) -> String {
        let length = value.count
        var result: String
        switch length {
        case ...4:
            result = group(value, uppercase: uppercase)
        case 5...8:
            result = group(String(value.prefix(length - 4)), uppercase: uppercase)
                + groups.0
                + group(String(value.suffix(4)), uppercase: uppercase)
        case 9...12:
            let head = String(value.prefix(length - 8))
            let middle = String(value.dropFirst(length - 8).prefix(4))
            result = group(head, uppercase: uppercase)
                + groups.1
                + group(middle, uppercase: uppercase)
                + groups.0
                + group(String(value.suffix(4)), uppercase: uppercase)
        default:
            return "数值超限！"
        }
        if result.hasPrefix(zero) { result.removeFirst() }
        result = result.replacingOccurrences(of: zero + groups.0, with: "")
        result = result.replacingOccurrences(of: zero + groups.1, with: "")
        result = result.replacingOccurrences(of: zero + zero, with: zero)
        if result.hasSuffix(zero) { result.removeLast() }
        if length > 4, result.hasPrefix(one + ten) { result.removeFirst(one.count) }
        // number.lua answers "数值超限！" here; a number that is just 0 reads better.
        if result.isEmpty { result = zero }
        return result + suffix
    }

    /// number.lua's `formatNum`: up to four digits with 十百千, or 0 itself.
    private static func group(_ value: String, uppercase: Bool) -> String {
        let digits = uppercase ? upperDigits : lowerDigits
        let units = uppercase ? upperUnits : lowerUnits
        guard value.count <= 4, Int(value) != 0 else { return digits[0] }
        var result = ""
        for (position, character) in value.reversed().enumerated() {
            guard let number = character.wholeNumberValue else { return "" }
            let digit = digits[number]
            result = digit == digits[0] ? digit + result : digit + units[position] + result
        }
        result = result.replacingOccurrences(of: digits[0] + digits[0], with: digits[0])
        if result.hasSuffix(digits[0]) { result.removeLast() }
        if result.hasSuffix(digits[0]) { result.removeLast() }
        return result
    }

    /// number.lua's `number2zh`: every digit of the fraction, zeros collapsed.
    private static func digits(_ fraction: String, uppercase: Bool) -> String {
        let figures = uppercase ? upperDigits : lowerDigits
        var result = fraction.compactMap(\.wholeNumberValue).map { figures[$0] }.joined()
        for _ in 0..<2 {
            result = result.replacingOccurrences(of: figures[0] + figures[0], with: figures[0])
        }
        return result
    }

    /// number.lua's `decimal_func`: four places at most, 角分厘毫, trailing zeros dropped.
    private static func fractionUnits(_ fraction: String, uppercase: Bool) -> String {
        let positions = ["角", "分", "厘", "毫"]
        let figures = uppercase ? upperDigits : lowerDigits
        var kept = String(fraction.prefix(4))
        while kept.hasSuffix("0") { kept.removeLast() }
        guard !kept.isEmpty else { return "整" }
        var result = ""
        for (position, character) in kept.enumerated() {
            let number = character.wholeNumberValue ?? 0
            result += number == 0 ? figures[0] : figures[number] + positions[position]
        }
        for _ in 0..<2 {
            result = result.replacingOccurrences(of: figures[0] + figures[0], with: figures[0])
        }
        return result
    }

    // MARK: - Time and date (shijian2.lua)

    private struct Moment {
        var year: Int
        var month: Int
        var day: Int
        var hour: Int
        var minute: Int
        var second: Int
        /// 1 = Sunday.
        var weekday: Int
        var dayOfYear: Int
        var daysInYear: Int
    }

    private static let monthAbbreviations = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ]
    private static let weekdayAbbreviations = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private static let weekdayNames = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
    private static let weekdaySpelled = ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"]
    private static let weekdayFullNames = [
        "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
    ]
    private static let shichenNames = [
        "子时(夜半｜三更)", "丑时(鸡鸣｜四更)", "寅时(平旦｜五更)", "卯时(日出)",
        "辰时(食时)", "巳时(隅中)", "午时(日中)", "未时(日昳)",
        "申时(哺时)", "酉时(日入)", "戌时(黄昏｜一更)", "亥时(人定｜二更)",
    ]

    private static func moment(_ context: Context) -> Moment? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = context.timeZone
        calendar.locale = Locale(identifier: "en_US_POSIX")
        let parts = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second, .weekday], from: context.now)
        guard let year = parts.year, let month = parts.month, let day = parts.day,
              let hour = parts.hour, let minute = parts.minute, let second = parts.second,
              let weekday = parts.weekday,
              let dayOfYear = calendar.ordinality(of: .day, in: .year, for: context.now),
              let days = calendar.range(of: .day, in: .year, for: context.now) else { return nil }
        return Moment(year: year, month: month, day: day, hour: hour, minute: minute,
                      second: second, weekday: weekday, dayOfYear: dayOfYear, daysInYear: days.count)
    }

    private static func padded(_ value: Int, width: Int = 2) -> String {
        String(format: "%0\(width)d", value)
    }

    /// shijian2.lua's `GetLunarSichen`: 子时 covers 23:00–01:00.
    private static func shichen(_ hour: Int) -> String {
        var index = (hour + 1) / 2 + 1
        if index > 12 { index -= 12 }
        return shichenNames[index - 1]
    }

    /// /time: 23:05, 下午11:05, 23:05:36, 23点05分36秒.
    private static func clock(_ context: Context) -> [Candidate]? {
        guard let now = moment(context) else { return nil }
        let shichen = shichen(now.hour)
        let hour12 = now.hour % 12 == 0 ? 12 : now.hour % 12
        var spoken = padded(now.hour) + "点" + padded(now.minute) + "分" + padded(now.second) + "秒"
        if spoken.hasPrefix("0") { spoken.removeFirst() } // lua: gsub("^0", "")
        return [
            Candidate(text: padded(now.hour) + ":" + padded(now.minute), comment: shichen),
            Candidate(text: (now.hour < 12 ? "上午" : "下午") + padded(hour12) + ":" + padded(now.minute),
                      comment: shichen),
            Candidate(text: padded(now.hour) + ":" + padded(now.minute) + ":" + padded(now.second),
                      comment: shichen),
            Candidate(text: spoken, comment: shichen),
        ]
    }

    /// /date: the seven formats of shijian2.lua, comment 当年第几天 / 365 或 366.
    private static func date(_ context: Context) -> [Candidate]? {
        guard let now = moment(context) else { return nil }
        let day = padded(now.dayOfYear, width: 3) + "/" + String(now.daysInYear)
        let year = String(now.year), month = padded(now.month), dayOfMonth = padded(now.day)
        return [
            Candidate(text: "\(year).\(month).\(dayOfMonth)", comment: day),
            Candidate(text: "\(year)-\(month)-\(dayOfMonth)", comment: day),
            Candidate(text: "\(year)年\(month)月\(dayOfMonth)日", comment: day),
            Candidate(text: "\(monthAbbreviations[now.month - 1]) \(now.day), \(year)", comment: day),
            Candidate(text: "\(now.month)/\(now.day)/\(year)", comment: day),
            Candidate(text: spelledDate(now), comment: day),
            Candidate(text: "\(year)\(month)\(dayOfMonth)", comment: day),
        ]
    }

    /// shijian2.lua's `CnDate_translator`: 二〇二六年十月二十二日.
    private static func spelledDate(_ now: Moment) -> String {
        let figures = ["〇", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
        let characters = Array(String(now.year) + padded(now.month) + padded(now.day))
        var result = ""
        for (position, character) in characters.enumerated() {
            var part = figures[character.wholeNumberValue ?? 0]
            switch position {
            case 4: part = part == "〇" ? "年" : "年十"
            case 5: part = part == "〇" ? "月" : part + "月"
            case 6:
                switch character.wholeNumberValue ?? 0 {
                case 0: part = ""
                case 1: part = "十"
                default: part += "十"
                }
            case 7: part = part == "〇" ? "日" : part + "日"
            default: break
            }
            result += part
        }
        return result
    }

    /// /week: 周四 / 星期四 / Thu / Thursday, comment 第NN周 (C's %W: Monday-based).
    private static func weekday(_ context: Context) -> [Candidate]? {
        guard let now = moment(context) else { return nil }
        let week = "第" + padded(weekOfYear(now, timeZone: context.timeZone)) + "周"
        let index = now.weekday - 1
        return [
            Candidate(text: weekdayNames[index], comment: week),
            Candidate(text: weekdaySpelled[index], comment: week),
            Candidate(text: weekdayAbbreviations[index], comment: week),
            Candidate(text: weekdayFullNames[index], comment: week),
        ]
    }

    /// C's `%W`: weeks start on Monday, and the days before the first Monday are week 0.
    private static func weekOfYear(_ now: Moment, timeZone: TimeZone) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let first = calendar.date(from: DateComponents(year: now.year, month: 1, day: 1))
        let weekday = first.map { calendar.component(.weekday, from: $0) } ?? 1
        let monday = (weekday + 5) % 7
        return (now.dayOfYear - 1 + monday) / 7
    }

    private static let lunarMonths = [
        "正月", "二月", "三月", "四月", "五月", "六月",
        "七月", "八月", "九月", "十月", "冬月", "腊月",
    ]
    private static let lunarDays = [
        "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
        "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
        "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十",
    ]
    private static let heavenlyStems = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
    private static let earthlyBranches = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]
    private static let zodiacs = ["鼠", "牛", "虎", "兔", "龙", "蛇", "马", "羊", "猴", "鸡", "狗", "猪"]

    /// /cdate: the lunar date, in the shapes shijian2.lua used (without 节气 and the
    /// 干支 month, which need the astronomical tables that were dropped with lua).
    private static func lunar(_ context: Context) -> [Candidate]? {
        guard let now = moment(context) else { return nil }
        var calendar = Calendar(identifier: .chinese)
        calendar.timeZone = context.timeZone
        let parts = calendar.dateComponents([.year, .month, .day, .isLeapMonth], from: context.now)
        guard let cycle = parts.year, let month = parts.month, let day = parts.day,
              (1...12).contains(month), (1...30).contains(day) else { return nil }
        let monthName = (parts.isLeapMonth == true ? "闰" : "") + lunarMonths[month - 1]
        let dayName = lunarDays[day - 1]
        let stem = heavenlyStems[(cycle - 1) % 10]
        let branch = earthlyBranches[(cycle - 1) % 12]
        let year = "\(stem)\(branch)年(\(zodiacs[(cycle - 1) % 12]))"
        return [
            Candidate(text: "农历" + monthName + dayName),
            Candidate(text: year + monthName + dayName),
            Candidate(text: year + monthName + dayName + shichen(now.hour)),
        ]
    }
}
