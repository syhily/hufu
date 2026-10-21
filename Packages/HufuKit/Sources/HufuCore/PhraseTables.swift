public import Foundation

/// A phrase table (`table_translator@custom_phrase` user_dict) and the schemas using it.
public struct PhraseTable: Sendable, Hashable, Identifiable {
    /// Table name, e.g. `huma_custom`.
    public let name: String
    public let schemas: [String]
    public let fileName: String
    public var id: String { name }

    public init(name: String, schemas: [String], fileName: String? = nil) {
        self.name = name
        self.schemas = schemas
        self.fileName = fileName ?? "\(name).txt"
    }

    /// The user table merged into tigress through `import_tables`.
    public static let hufu = PhraseTable(name: "huma_custom", schemas: ["tigress"], fileName: "huma_custom.dict.yaml")
}

public struct PhraseMergeResult: Sendable, Equatable {
    public var added: Int
    public var skipped: Int
}

extension CustomPhrases {
    /// Adds every valid phrase from `other` that is not already present.
    @discardableResult
    public mutating func merge(_ other: CustomPhrases) -> PhraseMergeResult {
        var result = PhraseMergeResult(added: 0, skipped: 0)
        var existing = Set(phrases.map { "\($0.text)\t\($0.code)" })
        for phrase in other.phrases {
            let key = "\(phrase.text)\t\(phrase.code)"
            if phrase.isValid, existing.insert(key).inserted {
                // Imported weights are dropped on purpose: rows without an explicit
                // weight float per the table header's semantics.
                phrases.append(Phrase(text: phrase.text, code: phrase.code, stem: phrase.stem))
                result.added += 1
            } else {
                result.skipped += 1
            }
        }
        return result
    }

    /// True for Rime text tables (custom_phrase-style files).
    public static func looksLikeTable(_ url: URL) -> Bool {
        guard url.pathExtension == "txt", let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        let head = String(decoding: (try? handle.read(upToCount: 512)) ?? Data(), as: UTF8.self)
        return head.contains("# Rime table") || head.contains("db_type\ttabledb")
    }
}

extension SettingsStore {
    public func phraseTableURL(_ table: PhraseTable) -> URL {
        paths.userDataDir.appendingPathComponent(table.fileName)
    }

    /// Merges phrases from `source` (a custom_phrase-style table) into `table`, backing
    /// the table up first.
    @discardableResult
    public func importPhrases(from source: URL, into table: PhraseTable) throws -> PhraseMergeResult {
        let destination = phraseTableURL(table)
        var current = CustomPhrases.loadDictionary(from: destination)
        let result = current.merge(CustomPhrases.load(from: source))
        guard result.added > 0 else { return result }
        if FileManager.default.fileExists(atPath: destination.path) {
            let backup = paths.hufuDir.appendingPathComponent("backup/phrases-\(Int(Date().timeIntervalSince1970))-\(table.fileName)")
            try FileManager.default.createDirectory(at: backup.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: destination, to: backup)
        }
        try current.saveDictionary(to: destination)
        return result
    }
}
