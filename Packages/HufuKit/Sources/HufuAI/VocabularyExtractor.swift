import Foundation

/// Finds names, brands and jargon in text the user pastes, so they can be added to
/// custom phrases. The model only selects terms; hufu codes are entered by the user.
public struct VocabularyExtractor: Sendable {
    public struct Term: Sendable, Hashable, Identifiable {
        public var id: String { text }
        public var text: String
        public var note: String
    }

    public let provider: any AIProvider

    public init(provider: any AIProvider) { self.provider = provider }

    static let instructions = """
    你帮助输入法用户从一段文字中找出值得加入个人词库的词：人名、品牌、产品、专业术语、网络新词、固定搭配。
    忽略常见词。严格只输出 JSON 数组，不要其他文字：[{"text":"词条","note":"简短类别"}]，最多 40 项。
    """

    public func extract(from text: String, excluding existing: Set<String> = []) async throws -> [Term] {
        let reply = try await provider.complete(instructions: Self.instructions, prompt: String(text.prefix(8000)))
        return try parse(reply, excluding: existing)
    }

    func parse(_ reply: String, excluding existing: Set<String>) throws -> [Term] {
        struct Item: Decodable { let text: String; let note: String? }
        guard let data = JSONExtractor.firstJSON(in: reply), let items = try? JSONDecoder().decode([Item].self, from: data)
        else { throw AIError.badResponse(String(reply.prefix(120))) }
        var seen = Set<String>()
        return items.compactMap { item in
            let text = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, text.count <= 24, !existing.contains(text), seen.insert(text).inserted else { return nil }
            return Term(text: text, note: item.note ?? "")
        }
    }
}
