import Foundation
import Testing
@testable import RimeKit

/// 繁简转换（st_tu）回归：开关打开时 `rk` 出「對」，关闭时出「对」。
/// 夹具用产品自带的 st_tu.json + STCharacters_Tu.txt（仓库内文件）与 librime
/// 预编译的 STPhrases.ocd2，不依赖 build/SharedSupport。
@MainActor
@Suite(.serialized)
struct TraditionalConversionTests {
    /// 仓库根（本文件位于 Packages/HufuKit/Tests/RimeKitTests/）。
    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    private static func makeWorkspace() throws -> (shared: URL, user: URL)? {
        let fm = FileManager.default
        let stockOCD2 = repoRoot.appendingPathComponent("Vendor/librime/share/opencc/STPhrases.ocd2")
        let stTu = repoRoot.appendingPathComponent("SharedSupport/opencc/st_tu.json")
        let stTuTable = repoRoot.appendingPathComponent("SharedSupport/opencc/STCharacters_Tu.txt")
        guard fm.fileExists(atPath: stockOCD2.path), fm.fileExists(atPath: stTu.path) else { return nil }

        let root = fm.temporaryDirectory.appendingPathComponent("hufu-trad-\(UUID().uuidString)")
        let shared = root.appendingPathComponent("shared")
        let user = root.appendingPathComponent("user")
        try fm.createDirectory(at: shared.appendingPathComponent("opencc"), withIntermediateDirectories: true)
        try fm.createDirectory(at: user, withIntermediateDirectories: true)
        for file in [stTu, stTuTable, stockOCD2] {
            try fm.copyItem(at: file, to: shared.appendingPathComponent("opencc/\(file.lastPathComponent)"))
        }
        try """
        config_version: "1"
        schema_list:
          - schema: test_trad
        menu:
          page_size: 5
        """.write(to: shared.appendingPathComponent("default.yaml"), atomically: true, encoding: .utf8)
        try """
        schema:
          schema_id: test_trad
          name: 简繁测试
          version: "1"
        switches:
          - name: ascii_mode
            reset: 0
            states: [ 中文, 西文 ]
          - name: simplification
            reset: 0
            states: [ 简中, 繁中 ]
        engine:
          processors: [ascii_composer, recognizer, key_binder, speller, punctuator, selector, navigator, express_editor]
          segmentors: [ascii_segmentor, matcher, abc_segmentor, punct_segmentor, fallback_segmentor]
          translators: [punct_translator, table_translator]
          filters:
            - simplifier@simplification
            - uniquifier
        speller:
          alphabet: "zyxwvutsrqponmlkjihgfedcba"
          max_code_length: 4
        translator:
          dictionary: test_trad
        simplification:
          opencc_config: st_tu.json
          option_name: simplification
          tips: none
        """.write(to: shared.appendingPathComponent("test_trad.schema.yaml"), atomically: true, encoding: .utf8)
        try """
        # Rime dictionary
        # encoding: utf-8
        ---
        name: test_trad
        version: "1"
        sort: by_weight
        columns: [text, code, weight]
        ...
        对	rk	100
        """.write(to: shared.appendingPathComponent("test_trad.dict.yaml"), atomically: true, encoding: .utf8)
        return (shared, user)
    }

    @Test func toggleConvertsAndDirectCodeStillWorks() throws {
        guard let workspace = try Self.makeWorkspace() else { return }
        let engine = RimeEngine.shared
        engine.initialize(RimeTraits(sharedDataDir: workspace.shared, userDataDir: workspace.user, minLogLevel: 2))
        engine.deployAndWait()
        defer { engine.finalize() }
        let session = try engine.createSession()

        session.setOption("simplification", true)
        for key in "rk".unicodeScalars { session.processKey(RimeKey.keysym(forCharacter: key)) }
        #expect(session.context().candidates.map(\.text).contains("對"))

        session.clearComposition()
        session.setOption("simplification", false)
        for key in "rk".unicodeScalars { session.processKey(RimeKey.keysym(forCharacter: key)) }
        #expect(session.context().candidates.map(\.text).contains("对"))
    }
}
