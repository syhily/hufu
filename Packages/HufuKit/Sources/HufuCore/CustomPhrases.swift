public import Foundation

/// `custom_phrase.txt`: a plain table of `text<TAB>code[<TAB>weight]` used by
/// `table_translator@custom_phrase`. Comment/header lines are preserved on save.
public struct CustomPhrases: Sendable, Equatable {
    public struct Phrase: Sendable, Hashable, Identifiable {
        public var id = UUID()
        public var text: String
        public var code: String
        public var weight: Int?
        /// Optional fourth column of a Rime table dictionary.
        public var stem: String?

        public init(text: String, code: String, weight: Int? = nil, stem: String? = nil) {
            self.text = text
            self.code = code
            self.weight = weight
            self.stem = stem
        }

        public static func == (lhs: Phrase, rhs: Phrase) -> Bool {
            lhs.text == rhs.text && lhs.code == rhs.code && lhs.weight == rhs.weight && lhs.stem == rhs.stem
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(text); hasher.combine(code); hasher.combine(weight); hasher.combine(stem)
        }

        /// Anything librime can read back: non-empty text and code without tabs or line
        /// breaks. Codes may contain spaces (e.g. `img 1`), which librime accepts.
        public var isValid: Bool {
            !text.isEmpty && !code.trimmingCharacters(in: .whitespaces).isEmpty
                && !text.contains("\t") && !text.contains("\n") && !code.contains("\t") && !code.contains("\n")
        }
    }

    public var header: [String]
    public var phrases: [Phrase]
    /// Non-comment lines that could not be parsed. Kept verbatim so saving never loses
    /// anything the user wrote.
    public var unparsed: [String] = []

    public static let defaultHeader = [
        "# Rime table",
        "# coding: utf-8",
        "#@/db_name\tcustom_phrase.txt",
        "#@/db_type\ttabledb",
        "#",
        "# 自定义短语 — managed by Hufu Settings; hand edits are kept.",
        "# 格式：词条<Tab>编码<Tab>权重（可选）",
        "#",
        "# 此行之后不能写注释",
    ]

    /// `huma_custom.dict.yaml`: entries merged into tigress through `import_tables`.
    public static let hufuDictionaryHeader = [
        "# Rime dictionary",
        "# encoding: utf-8",
        "#",
        "# hufu 用户自定义短语表，挂在 tigress 主词典的 import_tables 上。",
        "# 由「Hufu 设置」的自定义短语页维护；也可手工添加，每行一条：",
        "#   词组<TAB>编码<TAB>权重",
        "# 编码为虎码，权重可省略。修改后几秒内自动生效。",
        "---",
        "name: huma_custom",
        "version: \"1\"",
        "sort: by_weight",
        "use_preset_vocabulary: false",
        "columns:",
        "  - text",
        "  - code",
        "  - weight",
        "  - stem",
        "...",
    ]

    /// Rows without an explicit weight sort above the base dictionary's words.
    public static let defaultDictionaryWeight = 1_000_000

    public init(header: [String] = CustomPhrases.defaultHeader, phrases: [Phrase] = []) {
        self.header = header
        self.phrases = phrases
    }

    public init(parsing text: String) {
        var header: [String] = []
        var phrases: [Phrase] = []
        var unparsed: [String] = []
        for line in text.components(separatedBy: .newlines) {
            if line.hasPrefix("#") {
                if phrases.isEmpty && unparsed.isEmpty { header.append(line) }
                continue
            }
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            let columns = line.components(separatedBy: "\t")
            guard columns.count >= 2, !columns[0].isEmpty, !columns[1].isEmpty,
                  columns.count == 2 || Int(columns[2].trimmingCharacters(in: .whitespaces)) != nil || columns[2].isEmpty
            else {
                unparsed.append(line)
                continue
            }
            let weight = columns.count > 2 ? Int(columns[2].trimmingCharacters(in: .whitespaces)) : nil
            phrases.append(Phrase(text: columns[0], code: columns[1], weight: weight))
        }
        self.init(header: header.isEmpty ? Self.defaultHeader : header, phrases: phrases)
        self.unparsed = unparsed
    }

    /// Parses a Rime table dictionary (`text<TAB>code<TAB>weight<TAB>stem`), keeping
    /// everything through the `...` header terminator.
    public init(parsingDictionary text: String) {
        let lines = text.components(separatedBy: .newlines)
        let terminator = lines.firstIndex { $0.trimmingCharacters(in: .whitespaces) == "..." }
        var header: [String]
        var body: ArraySlice<String>
        if let terminator {
            header = Array(lines[...terminator])
            body = lines[(terminator + 1)...]
        } else if lines.contains(where: { $0.hasPrefix("name:") || $0.trimmingCharacters(in: .whitespaces) == "---" }) {
            // A truncated YAML header is not a list of entries to reinterpret.
            header = lines
            body = lines[lines.endIndex...]
        } else {
            header = Self.hufuDictionaryHeader
            body = lines[...]
        }

        var phrases: [Phrase] = []
        var unparsed: [String] = []
        for line in body {
            if line.hasPrefix("#") { continue }
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            let columns = line.components(separatedBy: "\t")
            let weight = columns.count > 2 ? Int(columns[2].trimmingCharacters(in: .whitespaces)) : nil
            guard columns.count >= 2, !columns[0].isEmpty, !columns[1].isEmpty,
                  columns.count <= 2 || columns[2].trimmingCharacters(in: .whitespaces).isEmpty || weight != nil
            else {
                unparsed.append(line)
                continue
            }
            let stem = columns.count > 3 ? columns[3] : nil
            phrases.append(Phrase(text: columns[0], code: columns[1], weight: weight,
                                  stem: stem?.isEmpty == false ? stem : nil))
        }
        self.init(header: header, phrases: phrases)
        self.unparsed = unparsed
    }

    public static func load(from url: URL) -> CustomPhrases {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return CustomPhrases() }
        return CustomPhrases(parsing: text)
    }

    public static func loadDictionary(from url: URL) -> CustomPhrases {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return CustomPhrases(header: hufuDictionaryHeader)
        }
        return CustomPhrases(parsingDictionary: text)
    }

    public var serializedDictionary: String {
        var lines = header
        for phrase in phrases where phrase.isValid {
            // Weight is written only when set; weightless rows stay weightless so the
            // round trip through loadDictionary is lossless.
            var columns = [phrase.text, phrase.code]
            let stem = phrase.stem.flatMap { $0.isEmpty ? nil : $0 }
            if let weight = phrase.weight {
                columns.append(String(weight))
            } else if stem != nil {
                columns.append("")
            }
            if let stem { columns.append(stem) }
            lines.append(columns.joined(separator: "\t"))
        }
        lines.append(contentsOf: unparsed)
        return lines.joined(separator: "\n") + "\n"
    }

    public func saveDictionary(to url: URL) throws {
        try serializedDictionary.write(to: url, atomically: true, encoding: .utf8)
    }

    public var serialized: String {
        var lines = header
        for phrase in phrases where phrase.isValid {
            lines.append([phrase.text, phrase.code] .joined(separator: "\t") + (phrase.weight.map { "\t\($0)" } ?? ""))
        }
        lines.append(contentsOf: unparsed)
        return lines.joined(separator: "\n") + "\n"
    }

    public func save(to url: URL) throws {
        try serialized.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Adds a phrase unless the same text/code pair already exists. Returns whether added.
    /// Phrases added without a weight get the default boost that floats them above the
    /// base dictionary; imported rows stay weightless instead (see merge).
    @discardableResult
    public mutating func add(_ phrase: Phrase) -> Bool {
        guard phrase.isValid, !phrases.contains(where: { $0.text == phrase.text && $0.code == phrase.code }) else { return false }
        var phrase = phrase
        if phrase.weight == nil { phrase.weight = Self.defaultDictionaryWeight }
        phrases.append(phrase)
        return true
    }

    /// Removes the exact text/code pair. Returns whether something was removed.
    @discardableResult
    public mutating func remove(text: String, code: String) -> Bool {
        let before = phrases.count
        phrases.removeAll { $0.text == text && $0.code == code }
        return phrases.count != before
    }
}
