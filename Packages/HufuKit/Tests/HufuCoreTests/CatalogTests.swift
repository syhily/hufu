import Foundation
import Testing
@testable import HufuCore

struct CatalogTests {
    let catalog = SettingCatalog.bundled

    @Test func bundledCatalogIsWellFormed() {
        #expect(catalog.settings.count >= 40)
        let ids = catalog.settings.map(\.id)
        #expect(Set(ids).count == ids.count, "duplicate ids")
        let groups = Set(catalog.groups.map(\.id))
        for setting in catalog.settings {
            #expect(groups.contains(setting.group), "\(setting.id) has unknown group")
            #expect(["default", "schema", "frontend"].contains(setting.file), "\(setting.id) file")
            #expect(!setting.keypath.isEmpty && !setting.keypath.hasPrefix("/"), "\(setting.id) keypath")
            if setting.type == .enum { #expect(setting.options?.isEmpty == false, "\(setting.id) needs options") }
            if setting.keypath == "key_binder/bindings" { #expect(setting.items?.isEmpty == false, "\(setting.id) needs items") }
        }
    }

    @Test func resolvesNamedSelectors() throws {
        let paths = HufuPaths(userDataDir: FileManager.default.temporaryDirectory.appendingPathComponent("hufu-cat-\(UUID().uuidString)"))
        try FileManager.default.createDirectory(at: paths.stagingDir, withIntermediateDirectories: true)
        try "schema_list:\n  - schema: demo\n".write(to: paths.builtConfig("default"), atomically: true, encoding: .utf8)
        try """
        switches:
          - name: ascii_mode
            reset: 0
          - name: emoji_cn
            reset: 1
        """.write(to: paths.builtConfig("demo.schema"), atomically: true, encoding: .utf8)
        let store = SettingsStore(paths: paths, catalog: catalog)
        #expect(store.resolve("switches/@name=emoji_cn/reset", target: .schema("demo")) == "switches/@1/reset")
        #expect(store.resolve("switches/@name=missing/reset", target: .schema("demo")) == nil)
        let emoji = try #require(catalog.setting("switches.emoji_cn"))
        #expect(store.value(for: emoji) == true)
    }
}

extension CatalogTests {
    /// Frontend options the Hufu candidate panel does not implement must not be offered
    /// (behavior must match the label).
    @Test func catalogOffersOnlyImplementedFrontendOptions() {
        let unsupported = ["style/text_orientation", "style/shadow_size", "style/show_paging", "style/memorize_size",
                           "style/mutual_exclusive", "keyboard_layout", "show_notifications_when"]
        let frontendKeys = catalog.settings.filter { $0.file == "frontend" }.map(\.keypath)
        #expect(frontendKeys.allSatisfy { !unsupported.contains($0) })
    }
}
