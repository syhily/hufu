public import Foundation

/// 简繁四模式 (Settings › 输入习惯 › 简繁模式).
///
/// 1. 混打: everything the dictionary offers, reordered — simplified candidates by
///    《通用规范汉字表》 tier first, then the rest, then the traditional forms.
/// 2. 打简出繁: librime's `simplification` converts the candidates, and the result must
///    still belong to 只打简体's universe: a form is kept when it is itself a standard
///    character or a traditional form of one.
/// 3. 只打繁体: conversion on, plus dropping candidates that still contain a glyph with
///    a traditional counterpart (i.e. the conversion left a simplified character).
/// 4. 只打简体: conversion off, plus dropping candidates outside 《通用规范汉字表》.
public enum ScriptMode: String, Sendable, Codable, CaseIterable, Equatable {
    case mixed
    case tradOutput
    case tradOnly
    case simpOnly

    /// Whether librime's `simplification` option belongs on for this mode.
    public var usesTraditionalConversion: Bool {
        switch self {
        case .tradOutput, .tradOnly: true
        case .mixed, .simpOnly: false
        }
    }

    /// The mode actually in force for one session. ⌃O / ⌃⇧4 flip librime's option for the
    /// moment, so it moves between the two modes that share a script: 混打 ↔ 打简出繁, or
    /// 只打简体 ↔ 只打繁体. The stored preference is untouched.
    public func resolved(traditional: Bool) -> ScriptMode {
        switch self {
        case .mixed, .tradOutput: traditional ? .tradOutput : .mixed
        case .tradOnly, .simpOnly: traditional ? .tradOnly : .simpOnly
        }
    }

    /// Only 混打 keeps every candidate; 打简出繁 and both "only" modes drop some.
    public var filters: Bool { self == .tradOnly || self == .simpOnly }
}

/// Character tables behind 简繁: 《通用规范汉字表》 in its published order and the
/// 虎码 simplified→traditional conversion (`opencc/STCharacters_Tu.txt`). Read once per
/// process and shared by all four modes.
public struct ScriptFilter: Sendable, Equatable {
    /// Tiers of 《通用规范汉字表》 by position: 一级 1–3500, 二级 3501–6500, 三级 6501–8105.
    public static let tierBoundaries = (first: 3500, second: 6500)

    /// `STCharacters_Tu.txt`: 简体字 → the forms it converts to. A row may carry several
    /// (为 → 爲/為, 发 → 發/髮).
    public let conversions: [Character: [Character]]
    /// 《通用规范汉字表》 in its published order; the position decides the tier.
    public let common: [Character]

    /// Simplified characters that have a traditional counterpart: a `conversions` key
    /// whose output list does not contain the character itself. `你 → 你/妳` and
    /// `了 → 了/瞭` keep 你/了 as acceptable traditional output (a variant at most), so
    /// those characters are ordinary text; `对 → 對`, `发 → 發/髮`, `马 → 馬` are not.
    /// The table lists 672 such self-preserving keys (`万 → 萬/万` included).
    public let convertible: Set<Character>
    /// `conversions` values whose simplified source is inside the table — what 打简出繁
    /// may show once librime has converted the candidate.
    public let convertedFromCommon: Set<Character>
    /// Every `conversions` value, whatever its source: 混打 puts these last.
    public let traditionalForms: Set<Character>

    /// Character → its position in the table (0-based).
    private let positions: [Character: Int]

    public init(conversions: [Character: [Character]], common: [Character]) {
        self.conversions = conversions
        self.common = common
        let positions = Dictionary(common.enumerated().map { ($0.element, $0.offset) }, uniquingKeysWith: { first, _ in first })
        self.positions = positions
        self.convertible = Set(conversions.compactMap { source, targets in
            targets.contains(source) ? nil : source
        })
        var fromCommon: Set<Character> = []
        var forms: Set<Character> = []
        for (source, targets) in conversions {
            forms.formUnion(targets)
            if positions[source] != nil { fromCommon.formUnion(targets) }
        }
        self.convertedFromCommon = fromCommon
        self.traditionalForms = forms
    }

    public static let sharedDataFiles = (convertible: "opencc/STCharacters_Tu.txt", common: "hufu/tgf-8105.txt")

    /// Reads both tables from the shipped `SharedSupport` directory. A missing file
    /// leaves its table empty, which disables the rules that depend on it rather than
    /// hiding every candidate.
    public static func load(sharedDataDir: URL?) -> ScriptFilter {
        guard let sharedDataDir else { return ScriptFilter(conversions: [:], common: []) }
        return ScriptFilter(
            conversions: conversions(at: sharedDataDir.appendingPathComponent(sharedDataFiles.convertible)),
            common: characters(at: sharedDataDir.appendingPathComponent(sharedDataFiles.common))
        )
    }

    /// Lines are `简体<TAB>繁体…`; values are space separated.
    private static func conversions(at url: URL) -> [Character: [Character]] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
        var result: [Character: [Character]] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            guard !line.hasPrefix("#") else { continue }
            let columns = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            guard columns.count == 2, columns[0].count == 1, let source = columns[0].first else { continue }
            let targets = columns[1].split(whereSeparator: \.isWhitespace).compactMap { $0.count == 1 ? $0.first : nil }
            guard !targets.isEmpty else { continue }
            result[source] = targets
        }
        return result
    }

    private static func characters(at url: URL) -> [Character] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        var result: [Character] = []
        for line in text.split(whereSeparator: \.isNewline) {
            let field = line.trimmingCharacters(in: .whitespaces)
            guard !field.hasPrefix("#"), field.count == 1, let character = field.first else { continue }
            result.append(character)
        }
        return result
    }

    /// 1, 2 or 3 for the three tiers of the table, nil for characters outside it.
    public func tier(of character: Character) -> Int? {
        guard let position = positions[character] else { return nil }
        return position < Self.tierBoundaries.first ? 1 : position < Self.tierBoundaries.second ? 2 : 3
    }

    /// Indices into `candidates` in display order: displayIndex → rimeIndex. 混打 sorts
    /// them into groups, the other modes drop some, and a mode with nothing to do leaves
    /// the identity.
    public func order(_ candidates: [String], mode: ScriptMode) -> [Int] {
        switch mode {
        case .mixed:
            return mixedOrder(candidates)
        case .tradOutput, .tradOnly, .simpOnly:
            return candidates.indices.filter { keeps(candidates[$0], mode: mode) }
        }
    }

    /// Only CJK characters decide a candidate's fate; punctuation, letters and digits in
    /// it neither help nor hurt.
    public func keeps(_ text: String, mode: ScriptMode) -> Bool {
        switch mode {
        case .mixed:
            return true
        case .tradOutput:
            // 打简出繁 keeps 只打简体's universe, judged on the converted text: a standard
            // character, or a traditional form whose simplified source is standard.
            guard !common.isEmpty else { return true }
            return text.allSatisfy { !Self.isHan($0) || isStandard($0) || convertedFromCommon.contains($0) }
        case .tradOnly:
            return !text.contains(where: convertible.contains)
        case .simpOnly:
            guard !common.isEmpty else { return true }
            return text.allSatisfy { !Self.isHan($0) || isStandard($0) }
        }
    }

    private func isStandard(_ character: Character) -> Bool { positions[character] != nil }

    /// 混打: 简体 (tier 1 → 2 → 3) → 其他 → 繁体, each group keeping the dictionary's order.
    /// A word's tier is the highest tier among its characters.
    private func mixedOrder(_ candidates: [String]) -> [Int] {
        guard !common.isEmpty else { return Array(candidates.indices) }
        return candidates.indices
            .map { index -> (group: Int, tier: Int, index: Int) in
                let (group, tier) = classification(of: candidates[index])
                return (group, tier, index)
            }
            .sorted { ($0.group, $0.tier, $0.index) < ($1.group, $1.tier, $1.index) }
            .map(\.index)
    }

    /// (0, tier) simplified, (1, 0) anything else, (2, 0) traditional.
    private func classification(of text: String) -> (group: Int, tier: Int) {
        var worst = 0
        var hasHan = false
        var simplified = true
        for character in text where Self.isHan(character) {
            hasHan = true
            guard let level = tier(of: character) else {
                simplified = false
                break
            }
            worst = max(worst, level)
        }
        if hasHan, simplified { return (0, worst) }
        if text.contains(where: traditionalForms.contains) { return (2, 0) }
        return (1, 0)
    }

    /// 4E00–9FFF (BMP), 3400–4DBF (extension A), 20000–3134F (B, C, D, E and the
    /// compatibility supplement), plus the CJK radical blocks 2E80–2EFF / 2F00–2FDF: the
    /// dictionary offers radicals as candidates (⻢ for `nm`), and they are not standard
    /// characters either.
    static func isHan(_ character: Character) -> Bool {
        guard character.unicodeScalars.count == 1, let value = character.unicodeScalars.first?.value else { return false }
        return (0x2E80...0x2EFF).contains(value) || (0x2F00...0x2FDF).contains(value)
            || (0x3400...0x4DBF).contains(value) || (0x4E00...0x9FFF).contains(value)
            || (0x20000...0x3134F).contains(value)
    }
}
