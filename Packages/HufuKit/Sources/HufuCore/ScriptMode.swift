public import Foundation

/// 简繁四模式 (Settings › 输入习惯 › 简繁模式).
///
/// 1. 混打: the dictionary's own order — simplified candidates first, the traditional
///    spellings that share a code reachable after them. Nothing to do.
/// 2. 打简出繁: librime's `simplification` switch converts the candidates; no filtering.
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

    /// A filter only runs for the two "only" modes.
    public var filters: Bool { self == .tradOnly || self == .simpOnly }
}

/// Character tables behind the candidate filter, read once per process.
public struct ScriptFilter: Sendable, Equatable {
    /// Simplified characters that have a traditional counterpart — the keys of
    /// `opencc/STCharacters_Tu.txt`.
    public let convertible: Set<Character>
    /// 《通用规范汉字表》 (8105 characters), `hufu/tgf-8105.txt`.
    public let common: Set<Character>

    public init(convertible: Set<Character>, common: Set<Character>) {
        self.convertible = convertible
        self.common = common
    }

    public static let sharedDataFiles = (convertible: "opencc/STCharacters_Tu.txt", common: "hufu/tgf-8105.txt")

    /// Reads both tables from the shipped `SharedSupport` directory. A missing file
    /// leaves its set empty, which disables the rule that depends on it rather than
    /// hiding every candidate.
    public static func load(sharedDataDir: URL?) -> ScriptFilter {
        guard let sharedDataDir else { return ScriptFilter(convertible: [], common: []) }
        return ScriptFilter(
            convertible: characters(at: sharedDataDir.appendingPathComponent(sharedDataFiles.convertible), firstColumn: true),
            common: characters(at: sharedDataDir.appendingPathComponent(sharedDataFiles.common), firstColumn: false)
        )
    }

    private static func characters(at url: URL, firstColumn: Bool) -> Set<Character> {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        var result: Set<Character> = []
        for line in text.split(whereSeparator: \.isNewline) {
            guard !line.hasPrefix("#") else { continue }
            let field = firstColumn ? line.prefix { $0 != "\t" } : line
            guard field.count == 1, let character = field.first else { continue }
            result.insert(character)
        }
        return result
    }

    /// Indices into `candidates` that stay, in display order: displayIndex → rimeIndex.
    /// Modes without a filter keep everything, so the mapping is the identity.
    public func keep(_ candidates: [String], mode: ScriptMode) -> [Int] {
        guard mode.filters else { return Array(candidates.indices) }
        return candidates.indices.filter { keeps(candidates[$0], mode: mode) }
    }

    /// Only CJK characters decide a candidate's fate; punctuation, letters and digits in
    /// it neither help nor hurt.
    public func keeps(_ text: String, mode: ScriptMode) -> Bool {
        switch mode {
        case .mixed, .tradOutput:
            return true
        case .tradOnly:
            return !text.contains(where: convertible.contains)
        case .simpOnly:
            guard !common.isEmpty else { return true }
            return text.allSatisfy { !Self.isHan($0) || common.contains($0) }
        }
    }

    /// 4E00–9FFF (BMP), 3400–4DBF (extension A), 20000–3134F (B, C, D, E and the
    /// compatibility supplement): the range that carries dictionary characters.
    static func isHan(_ character: Character) -> Bool {
        guard character.unicodeScalars.count == 1, let value = character.unicodeScalars.first?.value else { return false }
        return (0x3400...0x4DBF).contains(value) || (0x4E00...0x9FFF).contains(value) || (0x20000...0x3134F).contains(value)
    }
}
