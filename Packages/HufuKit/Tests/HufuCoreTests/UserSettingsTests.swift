import Foundation
import Testing
@testable import HufuCore

struct UserSettingsTests {
    let paths: HufuPaths

    init() throws {
        paths = HufuPaths(userDataDir: FileManager.default.temporaryDirectory
            .appendingPathComponent("hufu-user-\(UUID().uuidString)"))
        try FileManager.default.createDirectory(at: paths.stagingDir, withIntermediateDirectories: true)
        try "schema_list:\n  - schema: tigress\n".write(
            to: paths.builtConfig("default"), atomically: true, encoding: .utf8)
    }

    @Test func featureChangeWritesItsSchemaMountInTheSameCall() throws {
        let settings = UserSettings(paths: paths)
        let update = try settings.updateFeatures {
            $0.wordsEnabled = true
            $0.scriptMode = .tradOnly
        }
        #expect(update == .init(featuresChanged: true, schemaChanged: true))
        #expect(settings.features.wordsEnabled)
        #expect(settings.features.scriptMode == .tradOnly)

        let patch = try ConfigLayers(paths: paths).generatedPatch(.schema("tigress"))
        let tags = Dictionary(uniqueKeysWithValues: patch
            .filter { $0.key.hasSuffix("/tag") }
            .map { ($0.key, $0.value.stringValue) })
        #expect(tags["words_simp/tag"] == "words_simp")
        #expect(tags["words_trad/tag"] == "words_trad")
        #expect(tags["words_tradown/tag"] == "abc")
    }

    @Test func reconcileRepairsACrashBetweenSwitchAndDeploy() throws {
        try UserSettings(paths: paths).updateFeatures { $0.wordsEnabled = true; $0.scriptMode = .mixed }
        let layers = ConfigLayers(paths: paths)
        try layers.updateGenerated(.schema("tigress")) { patch in
            patch.removeAll { $0.key.hasSuffix("/tag") }
        }
        #expect(try UserSettings(paths: paths).reconcileSchema())
        let patch = try layers.generatedPatch(.schema("tigress"))
        #expect(patch.contains { $0.key == "words_simp/tag" && $0.value == .string("abc") })
    }

    @Test func scriptVariantIsOwnedByTheGeneratedLayer() throws {
        let settings = UserSettings(paths: paths)
        #expect(settings.scriptVariant == "st_tu.json")
        #expect(try settings.setScriptVariant("s2hk.json"))
        #expect(settings.scriptVariant == "s2hk.json")
        let patch = try ConfigLayers(paths: paths).generatedPatch(.schema("tigress"))
        #expect(patch.last { $0.key == "simplification/opencc_config" }?.value == .string("s2hk.json"))
        #expect(try settings.setScriptVariant("s2hk.json") == false)
        #expect(try settings.setScriptVariant("not-a-table.json") == false)
    }

    @Test func settingOwnsValueValidation() {
        let integer = SettingCatalog.Setting(
            id: "menu.page_size", group: "general", title: "", file: "default",
            keypath: "menu/page_size", type: .int, min: 1, max: 10)
        #expect(integer.validate(.int(5)) == .int(5))
        #expect(integer.validate(.double(5.6)) == .int(6))
        #expect(integer.validate(.string("7")) == .int(7))
        #expect(integer.validate(.int(0)) == nil)
        #expect(integer.validate(.int(11)) == nil)

        let toggle = SettingCatalog.Setting(
            id: "switch", group: "general", title: "", file: "schema",
            keypath: "switches/@name=emoji_cn/reset", type: .bool)
        #expect(toggle.validate(.int(1)) == .bool(true))
        #expect(toggle.validate(.string("false")) == .bool(false))

        let listToggle = SettingCatalog.Setting(
            id: "keys.paging", group: "keys", title: "", file: "schema",
            keypath: "key_binder/bindings", type: .bool,
            items: [.map([.init("accept", .string("minus"))])])
        #expect(listToggle.validate(.bool(true)) == .bool(true))
    }
}
