import SwiftUI

enum Pane: String, CaseIterable, Identifiable, Hashable {
    case overview, general, switching, keys, appearance, apps, dictionaries, phrases, snippets, sync, stats, ai, advanced, about

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .overview: "概览"
        case .general: "输入习惯"
        case .switching: "中英切换"
        case .keys: "快捷键"
        case .appearance: "外观"
        case .apps: "应用"
        case .dictionaries: "词库"
        case .phrases: "自定义短语"
        case .snippets: "常用语"
        case .sync: "同步与备份"
        case .stats: "输入统计"
        case .ai: "AI 助手"
        case .advanced: "高级"
        case .about: "关于"
        }
    }

    var symbol: String {
        switch self {
        case .overview: "sparkles.rectangle.stack"
        case .general: "keyboard"
        case .switching: "globe"
        case .keys: "command"
        case .appearance: "paintpalette"
        case .apps: "square.grid.2x2"
        case .dictionaries: "books.vertical"
        case .phrases: "text.quote"
        case .snippets: "list.bullet.rectangle"
        case .sync: "arrow.triangle.2.circlepath"
        case .stats: "chart.bar.xaxis"
        case .ai: "wand.and.sparkles"
        case .advanced: "wrench.and.screwdriver"
        case .about: "info.circle"
        }
    }

    /// Catalog group rendered generically by this pane, if any.
    var catalogGroup: String? {
        switch self {
        case .general: "general"
        case .switching: "switching"
        case .keys: "keys"
        default: nil
        }
    }

    @MainActor static let sections: [(LocalizedStringKey, [Pane])] = [
        ("", [.overview]),
        ("智能", [.ai, .stats]),
        ("输入", [.general, .switching, .keys]),
        ("个性化", [.appearance, .apps]),
        ("词库", [.dictionaries, .phrases, .snippets, .sync]),
        ("系统", [.advanced, .about]),
    ]
}

struct RootView: View {
    @Environment(SettingsModel.self) private var model
    @Binding var selection: Pane?

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                brandHeader
                ForEach(Pane.sections, id: \.1) { title, panes in
                    Section(title) {
                        ForEach(panes) { pane in
                            paneRow(pane)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(Theme.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            detail(for: selection ?? .overview)
                .background(Theme.canvas)
        }
        .tint(Theme.accent)
        .onboardingHost(bypassed: selection == .about)
        .themeImportHost(model)
        .overlay(alignment: .bottom) { ErrorBanner() }
        // The input method's quick menu opens a specific pane in a running Settings app.
        .onReceive(DistributedNotificationCenter.default().publisher(for: .init("dev.yufan.hufu.settings.showPane"))) { note in
            if let raw = note.userInfo?["pane"] as? String, let pane = Pane(rawValue: raw) {
                selection = pane
                NSApp.activate()
            }
        }
    }

    // Brand mark instead of a bare system sidebar.
    private var brandHeader: some View {
        HStack(spacing: 10) {
            Image("HufuSquare")
                .resizable().frame(width: 32, height: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("虎符输入法").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
                Text("Hufu · 设置").font(.caption2).foregroundStyle(Theme.secondaryText)
            }
        }
        .padding(.vertical, 6)
        .listRowSeparator(.hidden)
        .selectionDisabled()
    }

    private func paneRow(_ pane: Pane) -> some View {
        Label {
            Text(pane.title)
        } icon: {
            Image(systemName: pane.symbol).foregroundStyle(selection == pane ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
        }
        .tag(pane)
    }

    @ViewBuilder
    private func detail(for pane: Pane) -> some View {
        switch pane {
        case .overview: OverviewView(selection: $selection)
        case .appearance: AppearanceView()
        case .apps: AppOptionsView()
        case .dictionaries: DictionariesView()
        case .phrases: PhrasesView()
        case .snippets: SnippetsView()
        case .sync: SyncView()
        case .stats: UsageStatsView()
        case .ai: AIAssistantView()
        case .advanced: AdvancedView()
        case .about: AboutView()
        default: CatalogPane(pane: pane)
        }
    }
}

struct ErrorBanner: View {
    @Environment(SettingsModel.self) private var model

    var body: some View {
        if let error = model.lastError {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.octagon.fill").foregroundStyle(.red)
                Text(error).lineLimit(2).textSelection(.enabled)
                Spacer()
                Button("关闭") { model.dismissError() }.buttonStyle(.borderless)
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.red.opacity(0.25)))
            .padding(16)
            .frame(maxWidth: 640)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

/// Launch arguments used by screenshot automation (scripts/ui-shots.sh):
/// `--pane <id>` opens a pane, `--appearance light|dark` forces the appearance,
/// `--import-theme-url <hufu-ime://theme…>` opens the theme import sheet.
enum LaunchOptions {
    static func argument(_ name: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: name), index + 1 < args.count else { return nil }
        return args[index + 1]
    }

    static var pane: Pane? { argument("--pane").flatMap(Pane.init(rawValue:)) }
}
