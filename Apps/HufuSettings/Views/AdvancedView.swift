import AppKit
import SwiftUI

/// System tools that do not fit the settings catalog: the user directory, logs and the
/// first-run guide.
struct AdvancedView: View {
    @Environment(SettingsModel.self) private var model

    var body: some View {
        Form {
            Section {
                PaneHeader(title: "高级", subtitle: "打开用户目录、查看日志，或重新运行首次启动的引导。虎码方案由 Hufu 维护，设置中不提供方案定制。", symbol: "wrench.and.screwdriver")
            }
            Section("工具") {
                HStack(spacing: 10) {
                    Button { NSWorkspace.shared.open(model.paths.userDataDir) } label: {
                        Label("打开用户目录", systemImage: "folder")
                    }
                    Button { NSWorkspace.shared.open(model.paths.logDir) } label: {
                        Label("日志", systemImage: "doc.text.magnifyingglass")
                    }
                    RerunOnboardingButton()
                    Spacer()
                }
                LabeledContent("用户目录") {
                    Text(model.paths.userDataDir.path)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.cards)
    }
}
