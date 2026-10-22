import AppKit
import Testing
@testable import HufuCore
@testable import HufuPanel

/// Renders every color scheme of a frontend config offscreen, horizontal and vertical,
/// exactly as the candidate panel draws it. Used to check highlight corners across
/// schemes and to produce the website's theme images (scripts/render-themes.sh).
///
///     HUFU_RENDER_FRONTEND=<hufu.yaml> HUFU_RENDER_OUT=<dir> swift test --filter ThemeRenderProbe
///
/// Optional HUFU_RENDER_SCHEMES=a,b limits the schemes; HUFU_RENDER_PREEDIT=1 shows the
/// pinyin row (inline preedit otherwise, as in most apps).
@MainActor
@Suite struct ThemeRenderProbe {
    static let state = PanelState(
        preedit: "huma",
        preeditSelection: NSRange(location: 0, length: 4),
        candidates: [
            .init(label: "1", text: "虎码", comment: "输入法"),
            .init(label: "2", text: "虎符"),
            .init(label: "3", text: "虎"),
            .init(label: "4", text: "虎符输入法", comment: "产品"),
            .init(label: "5", text: "Hufu", comment: "英"),
            .init(label: "6", text: "呼玛", comment: "地名"),
        ],
        highlightedIndex: 0
    )

    @Test func render() throws {
        let env = ProcessInfo.processInfo.environment
        guard let source = env["HUFU_RENDER_FRONTEND"], let out = env["HUFU_RENDER_OUT"] else { return }
        let frontend = try ConfigValue.parse(yaml: String(contentsOfFile: source, encoding: .utf8))
        let only = env["HUFU_RENDER_SCHEMES"].map { Set($0.split(separator: ",").map(String.init)) }
        try FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
        for (id, _) in PanelTheme.schemeNames(in: frontend) where only?.contains(id) ?? true {
            for layout in ["linear", "stacked"] {
                var config = frontend
                config.set(.string(id), at: "style/color_scheme")
                config.set(.string(id), at: "style/color_scheme_dark")
                config.set(.string(layout), at: "style/hufu/candidate_list_layout")
                config.set(false, at: "style/hufu/translucency")
                let theme = PanelTheme(frontend: config, dark: false)
                let view = CandidateView()
                view.forcePreedit = env["HUFU_RENDER_PREEDIT"] == "1"
                view.theme = theme
                view.state = Self.state
                view.layoutSubtreeIfNeeded()
                let size = view.fittingSize
                view.frame = NSRect(origin: .zero, size: size)
                try write(view, to: URL(fileURLWithPath: out).appendingPathComponent("\(id)-\(layout).png"))
            }
        }
    }

    private func write(_ view: NSView, to url: URL) throws {
        let scale = 2.0
        let size = view.bounds.size
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return }
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        view.displayIgnoringOpacity(view.bounds, in: NSGraphicsContext.current!)
        NSGraphicsContext.restoreGraphicsState()
        try rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
