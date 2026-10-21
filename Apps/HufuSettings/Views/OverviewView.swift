import HufuCore
import HufuPanel
import SwiftUI
import UniformTypeIdentifiers

struct OverviewView: View {
    @Environment(SettingsModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selection: Pane?
    @State private var showingImport = false

    var body: some View {
        PaneColumn {
            VStack(alignment: .leading, spacing: 20) {
                hero
                statusGrid
                importCard
                quickLinks
                VersionFooter().id("version")
            }
        }
        .scrollTargetForScreenshots()
    }

    private var hero: some View {
        // Side by side when there is room; the preview drops below the copy otherwise,
        // so the text column is never squeezed into a few characters per line.
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 28) {
                heroCopy
                Spacer(minLength: 12)
                heroPreview
            }
            VStack(alignment: .leading, spacing: 20) {
                heroCopy
                heroPreview
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.cardBorder))
    }

    private var heroCopy: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image("HufuLockup")
                .resizable().scaledToFit().frame(width: 240, height: 89)
                .accessibilityLabel("Hufu 虎符输入法")
            Text("中文常新，自在表达。")
                .font(.title3.weight(.medium)).foregroundStyle(Theme.secondaryText)
            Text("可视化管理外观、词库与短语")
                .font(.title3).foregroundStyle(Theme.secondaryText)
            HStack(spacing: 8) {
                Tag(text: "librime 1.17", symbol: "cpu")
                Tag(text: model.enabledSchemas.first.map { $0 == "tigress" ? "主方案 虎码" : "主方案 \($0)" } ?? "尚未生效",
                    symbol: "character.book.closed")
            }
        }
        .fixedSize()
    }

    private var heroPreview: some View {
        PanelPreview(theme: model.theme(dark: colorScheme == .dark))
            .fixedSize()
            .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
    }

    private var statusGrid: some View {
        Grid(horizontalSpacing: 14, verticalSpacing: 14) {
            GridRow {
                let state = model.inputSourceState
                StatusCard(
                    title: "输入法",
                    value: !model.isInstalled ? "未安装" : state == .ready ? "已启用" : state == .needsRelogin ? "还差一步" : "已安装",
                    detail: !model.isInstalled ? "运行 scripts/install-dev.sh 或安装 pkg"
                        : state == .ready ? "按 ⌃空格 切换到虎符输入法即可输入"
                        : state == .needsRelogin ? "注销或重启一次 Mac，虎符输入法才会出现在输入法列表里"
                        : "系统设置 › 键盘 › 输入法 中添加虎符输入法",
                    symbol: "keyboard.badge.ellipsis", ok: model.isInstalled && state == .ready
                )
                StatusCard(
                    title: "配置", value: model.isDeployed ? "已生效" : "等待首次应用",
                    detail: model.hasPendingChanges ? "正在应用更改…" : "配置与输入法一致",
                    symbol: "shippingbox", ok: model.isDeployed && !model.hasPendingChanges
                )
                StatusCard(
                    title: "输入方案", value: model.enabledSchemas.first.map { $0 == "tigress" ? "虎码" : $0 } ?? "未启用",
                    detail: "虎码官方秃版 · tigress",
                    symbol: "character.book.closed", ok: !model.enabledSchemas.isEmpty
                )
            }
        }
    }

    private var importCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "square.and.arrow.down.on.square").font(.title).foregroundStyle(Theme.accentText)
            VStack(alignment: .leading, spacing: 4) {
                Text(model.hasImported ? "重新导入 RIME 配置" : "导入 RIME 配置").font(.headline)
                Text("一键导入鼠须管等 RIME 目录的词库、自定义短语、配色与词频（只读，短语自动合并到虎码短语表；方案补丁不导入）。")
                    .font(.callout).foregroundStyle(Theme.secondaryText)
                ForEach(model.importWarnings, id: \.self) { warning in
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout).foregroundStyle(Theme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            Button(model.hasImported ? "重新导入…" : "导入…") { showingImport = true }
                .buttonStyle(.borderedProminent)
                .disabled(model.deployState == .deploying)
        }
        .padding(18)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .sheet(isPresented: $showingImport) { ImportSheet() }
        .task {
            // Screenshot automation: scripts can open the sheet with --import-sheet.
            if ProcessInfo.processInfo.arguments.contains("--import-sheet") {
                try? await Task.sleep(for: .milliseconds(400))
                showingImport = true
            }
        }
    }

    private var quickLinks: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("常用").font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
                ForEach([Pane.appearance, .general, .dictionaries, .phrases, .keys, .ai]) { pane in
                    Button { selection = pane } label: {
                        HStack(spacing: 10) {
                            Image(systemName: pane.symbol).frame(width: 22).foregroundStyle(Theme.accentText)
                            Text(pane.title).foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                        .padding(14)
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct StatusCard: View {
    let title: LocalizedStringKey
    let value: String
    let detail: String
    let symbol: String
    let ok: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: symbol).foregroundStyle(Theme.secondaryText)
                Text(title).font(.subheadline).foregroundStyle(Theme.secondaryText)
                Spacer()
                Circle().fill(ok ? Color.green : Color.orange).frame(width: 8, height: 8)
            }
            Text(value).font(.title3.weight(.semibold))
            Text(detail.isEmpty ? " " : detail).font(.caption).foregroundStyle(Theme.secondaryText).lineLimit(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct Tag: View {
    let text: String
    let symbol: String

    var body: some View {
        Label(text, systemImage: symbol)
            .lineLimit(1)
            .fixedSize()
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(.thinMaterial, in: Capsule())
    }
}

/// Version and diagnostics, at the bottom of the overview.
struct VersionFooter: View {
    @Environment(SettingsModel.self) private var model

    @State private var exporting = false
    @State private var exportNotice: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text("虎符输入法 \(model.currentVersion.description)\(model.isDistributionBuild ? "" : " · 开发版")")
                    .font(.caption).foregroundStyle(Theme.secondaryText)
                Spacer(minLength: 12)
                Button("导出诊断信息…") { exportDiagnostics() }
                    .disabled(exporting)
                    .controlSize(.small)
                    .help(Diagnostics.disclosure)
                if let exportNotice { Text(exportNotice).font(.caption).foregroundStyle(Theme.secondaryText) }
            }
        }
        .padding(.top, 4)
    }

    private func exportDiagnostics() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.zip]
        panel.nameFieldStringValue = Diagnostics.filename()
        panel.message = Diagnostics.disclosure
        panel.begin { response in
            guard response == .OK, let destination = panel.url else { return }
            exporting = true
            exportNotice = nil
            let report = Diagnostics(paths: model.paths)
            Task {
                do {
                    try await Task.detached(priority: .utility) { try report.export(to: destination) }.value
                    exportNotice = "诊断信息已导出"
                } catch { exportNotice = "导出失败，请检查保存位置的写入权限" }
                exporting = false
            }
        }
    }
}
