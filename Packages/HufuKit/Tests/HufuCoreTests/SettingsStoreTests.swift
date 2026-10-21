import Foundation
import Testing
@testable import HufuCore

struct SettingsStoreTests {
    let paths: HufuPaths
    let catalog: SettingCatalog

    init() throws {
        paths = HufuPaths(userDataDir: FileManager.default.temporaryDirectory.appendingPathComponent("hufu-store-\(UUID().uuidString)"))
        try FileManager.default.createDirectory(at: paths.stagingDir, withIntermediateDirectories: true)
        try """
        schema_list:
          - schema: tigress
        menu:
          page_size: 9
        """.write(to: paths.builtConfig("default"), atomically: true, encoding: .utf8)
        try """
        switches:
          - name: chaifen
            reset: 0
        key_binder:
          bindings:
            - { when: has_menu, accept: minus, send: Page_Up }
            - { when: has_menu, accept: equal, send: Page_Down }
        """.write(to: paths.builtConfig("tigress.schema"), atomically: true, encoding: .utf8)
        let json = """
        {"version":1,"groups":[{"id":"general","title":"输入习惯"},{"id":"keys","title":"快捷键"}],"settings":[
          {"id":"menu.page_size","group":"general","title":"候选词个数","file":"default","keypath":"menu/page_size","type":"int","min":1,"max":10,"default":5},
          {"id":"switches.chaifen","group":"general","title":"拆分提示","file":"schema","keypath":"switches/@name=chaifen/reset","type":"bool","default":false},
          {"id":"keys.paging","group":"keys","title":"用 - = 翻页","file":"schema","keypath":"key_binder/bindings","type":"bool","default":true,
           "items":[{"when":"has_menu","accept":"minus","send":"Page_Up"},{"when":"has_menu","accept":"equal","send":"Page_Down"}]}
        ]}
        """
        catalog = try JSONDecoder().decode(SettingCatalog.self, from: Data(json.utf8))
    }

    @Test func readsDeployedValuesAndSchemas() throws {
        let store = SettingsStore(paths: paths, catalog: catalog)
        #expect(store.enabledSchemas() == ["tigress"])
        #expect(store.value(for: catalog.setting("menu.page_size")!) == 9)
        #expect(store.value(for: catalog.setting("keys.paging")!) == true)
        #expect(store.value(for: catalog.setting("switches.chaifen")!) == false)
    }

    @Test func writesScalarIntoGeneratedLayer() throws {
        let store = SettingsStore(paths: paths, catalog: catalog)
        let setting = catalog.setting("menu.page_size")!
        try store.set(5, for: setting)
        #expect(store.value(for: setting) == 5)
        #expect(store.isCustomized(setting))
        #expect(throws: SettingsStore.WriteError.self) { try store.set(42, for: setting) }
        try store.reset(setting)
        #expect(store.value(for: setting) == 9)
    }

    @Test func togglesKeyBindingsWithoutDuplicates() throws {
        let store = SettingsStore(paths: paths, catalog: catalog)
        let paging = catalog.setting("keys.paging")!
        let keypath = paging.keypath

        try store.set(false, for: paging)
        #expect(store.value(for: paging) == false)
        #expect(store.list(target: .schema("tigress"), keypath: keypath).isEmpty)

        try store.set(true, for: paging)
        #expect(store.value(for: paging) == true)
        #expect(store.list(target: .schema("tigress"), keypath: keypath).count == 2)

        try store.set(true, for: paging)
        #expect(store.list(target: .schema("tigress"), keypath: keypath).count == 2)

        try store.reset(paging)
        #expect(!store.isCustomized(paging))
        #expect(store.value(for: paging) == true)
    }

    @Test func writesSwitchResetByName() throws {
        let store = SettingsStore(paths: paths, catalog: catalog)
        let setting = catalog.setting("switches.chaifen")!
        try store.set(true, for: setting)
        #expect(store.value(for: setting) == true)
        #expect(store.layers.generatedValue(.schema("tigress"), keypath: "switches/@0/reset") == true)
    }

    @Test func roundTripsYAMLWithQuoting() throws {
        let value: ConfigValue = .map([
            .init("patch", .map([
                .init("menu/page_size", 5),
                .init("style/font_face", "PingFang SC"),
                .init("punctuator/half_shape/,", "，"),
                .init("key", "true"),
                .init("list", ["a/b", "0x1234"]),
            ])),
        ])
        let yaml = try value.yamlString()
        #expect(try ConfigValue.parse(yaml: yaml) == value)
    }
}
