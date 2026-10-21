#!/usr/bin/env swift
// Renders Hufu's horizontal lockups: the bookmark mark, the custom rounded-stroke
// "Hufu" wordmark, and 虎符输入法 outlined from Noto Sans SC (SIL OFL 1.1).
//   swift scripts/gen-lockup.swift [NotoSansSC[wght].ttf]
// Without an argument it reuses /tmp/NotoSansSC.ttf, downloading the pinned font
// from assets/brand/hufu/base-v1/font-source.json when the cache is missing.
// Writes lockup-{color,black,white,reversed}.{svg,png}, refreshes tokens.json's
// latinWordmark paths, type-outlines.json's name record and manifest.json.
import AppKit
import CoreText
import CryptoKit
import ImageIO

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let base = root.appendingPathComponent("assets/brand/hufu/base-v1")

guard let tokens = try JSONSerialization.jsonObject(with: Data(contentsOf: base.appendingPathComponent("tokens.json"))) as? [String: Any],
      let mark = tokens["mark"] as? [String: Any],
      let tokensMarkPath = mark["path"] as? String,
      let wordmark = tokens["latinWordmark"] as? [String: Any],
      let latinPaths = wordmark["paths"] as? [String],
      let strokeWidthValue = wordmark["strokeWidth"] as? NSNumber else {
    fatalError("tokens.json has no mark path or latinWordmark paths")
}
let strokeWidth = CGFloat(strokeWidthValue.doubleValue)

// MARK: - Pinned brand font

struct FontSource: Decodable {
    let download: String
    let sha256: String
    let name_weight: Double
}
let fontSource = try JSONDecoder().decode(FontSource.self,
                                          from: Data(contentsOf: base.appendingPathComponent("font-source.json")))
let fontURL: URL
if CommandLine.arguments.count > 1 {
    fontURL = URL(fileURLWithPath: CommandLine.arguments[1])
} else {
    let cached = URL(fileURLWithPath: "/tmp/NotoSansSC.ttf")
    if !FileManager.default.fileExists(atPath: cached.path) {
        guard let remote = URL(string: fontSource.download) else { fatalError("bad font URL") }
        let semaphore = DispatchSemaphore(value: 0)
        var downloaded: Data?
        URLSession.shared.dataTask(with: remote) { data, _, error in
            downloaded = data
            if let error { FileHandle.standardError.write(Data("download failed: \(error)\n".utf8)) }
            semaphore.signal()
        }.resume()
        semaphore.wait()
        guard let data = downloaded else { fatalError("cannot download \(remote)") }
        try data.write(to: cached)
    }
    fontURL = cached
}
let fontData = try Data(contentsOf: fontURL)
let digest = SHA256.hash(data: fontData).map { String(format: "%02x", $0) }.joined()
guard digest == fontSource.sha256 else {
    fatalError("font SHA-256 \(digest) does not match the brand font \(fontSource.sha256)")
}
guard let descriptors = CTFontManagerCreateFontDescriptorsFromData(fontData as CFData) as? [CTFontDescriptor],
      let baseDescriptor = descriptors.first else { fatalError("cannot read font") }

// MARK: - Canvas and identity geometry

let canvasWidth: CGFloat = 542, canvasHeight: CGFloat = 200
let markOrigin = CGPoint(x: 28, y: 28), markScale: CGFloat = 1.2
let latinOrigin = CGPoint(x: 184, y: 28), latinScale: CGFloat = 1.32
let nameOrigin = CGPoint(x: 184, y: 172)
let nameSize: CGFloat = 57, nameTracking: CGFloat = 5, nameWeight = fontSource.name_weight
// Custom rounded-stroke lettering. Cap top 8, x-height top 28, baseline 60.
// The paths and stroke width come from tokens.json's latinWordmark, shared with
// scripts/brand/export-base.mjs so every lockup uses one source of truth.

// MARK: - SVG path parsing / building

func cgPath(_ d: String) -> CGPath {
    let expression = try! NSRegularExpression(pattern: "[A-Za-z]|[-+]?(?:[0-9]*\\.[0-9]+|[0-9]+)")
    let parts = expression.matches(in: d, range: NSRange(d.startIndex..., in: d))
        .map { String(d[Range($0.range, in: d)!]) }
    let path = CGMutablePath()
    var i = 0
    var point = CGPoint.zero
    func number() -> CGFloat {
        defer { i += 1 }
        guard i < parts.count, let value = Double(parts[i]) else { fatalError("bad SVG path: \(d)") }
        return CGFloat(value)
    }
    while i < parts.count {
        let command = parts[i]; i += 1
        switch command {
        case "M": point = CGPoint(x: number(), y: number()); path.move(to: point)
        case "L": point = CGPoint(x: number(), y: number()); path.addLine(to: point)
        case "H": point.x = number(); path.addLine(to: point)
        case "V": point.y = number(); path.addLine(to: point)
        case "C":
            let c1 = CGPoint(x: number(), y: number()), c2 = CGPoint(x: number(), y: number())
            point = CGPoint(x: number(), y: number()); path.addCurve(to: point, control1: c1, control2: c2)
        case "Q":
            let control = CGPoint(x: number(), y: number())
            point = CGPoint(x: number(), y: number()); path.addQuadCurve(to: point, control: control)
        case "Z", "z": path.closeSubpath()
        default: fatalError("unsupported SVG command \(command)")
        }
    }
    return path
}

// MARK: - Chinese name outline

let nameText = "虎符输入法"
let nameDescriptor = CTFontDescriptorCreateCopyWithAttributes(
    baseDescriptor, [kCTFontVariationAttribute: [NSNumber(value: 0x7767_6874): nameWeight]] as CFDictionary)
let nameFont = CTFontCreateWithFontDescriptor(nameDescriptor, nameSize, nil)
precondition((CTFontCopyPostScriptName(nameFont) as String).contains("NotoSansSC"), "font fell back")
let nameVariation = CTFontCopyVariation(nameFont) as? [NSNumber: NSNumber]
precondition(nameVariation?[NSNumber(value: 0x7767_6874)]?.doubleValue == nameWeight,
             "variation weight not applied")

let nameCharacters = Array(nameText.utf16)
var nameGlyphs = [CGGlyph](repeating: 0, count: nameCharacters.count)
precondition(CTFontGetGlyphsForCharacters(nameFont, nameCharacters, &nameGlyphs, nameCharacters.count),
             "虎符输入法 has missing glyphs")
var nameAdvances = [CGSize](repeating: .zero, count: nameGlyphs.count)
CTFontGetAdvancesForGlyphs(nameFont, .horizontal, nameGlyphs, &nameAdvances, nameGlyphs.count)
var nameCursor: CGFloat = 0
var nameCommands: [String] = []
func n(_ value: CGFloat) -> String { String(format: "%.4f", value) }
for (index, glyph) in nameGlyphs.enumerated() {
    if let outline = CTFontCreatePathForGlyph(nameFont, glyph, nil) {
        outline.applyWithBlock { pointer in
            let element = pointer.pointee
            func p(_ index: Int) -> String {
                let point = element.points[index]
                return "\(n(point.x + nameCursor)) \(n(-point.y))"
            }
            switch element.type {
            case .moveToPoint: nameCommands.append("M" + p(0))
            case .addLineToPoint: nameCommands.append("L" + p(0))
            case .addQuadCurveToPoint: nameCommands.append("Q" + p(0) + " " + p(1))
            case .addCurveToPoint: nameCommands.append("C" + p(0) + " " + p(1) + " " + p(2))
            case .closeSubpath: nameCommands.append("Z")
            @unknown default: fatalError("unknown path element")
            }
        }
    }
    nameCursor += nameAdvances[index].width + nameTracking
}
let nameWidth = nameCursor - nameTracking
let nameD = nameCommands.joined(separator: " ")
let namePath = cgPath(nameD)

// MARK: - Colors and drawing

func srgb(_ hex: String) -> CGColor {
    func component(_ range: Range<String.Index>) -> CGFloat {
        CGFloat(Int(hex[range], radix: 16)!) / 255
    }
    let digits = hex.dropFirst()
    let r = digits.startIndex..<digits.index(digits.startIndex, offsetBy: 2)
    let g = digits.index(digits.startIndex, offsetBy: 2)..<digits.index(digits.startIndex, offsetBy: 4)
    let b = digits.index(digits.startIndex, offsetBy: 4)..<digits.index(digits.startIndex, offsetBy: 6)
    return CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                   components: [component(r), component(g), component(b), 1])!
}
let vermilion = "#B64032", ink = "#242321", black = "#000000", white = "#FFFFFF"

struct Variant {
    let name: String
    let title: String
    let markColor: String
    let textColor: String
    let background: String?
    let rectRadius: CGFloat
}
let variants = [
    Variant(name: "lockup-color", title: "虎符输入法 Hufu 彩色横向组合",
            markColor: vermilion, textColor: ink, background: nil, rectRadius: 0),
    Variant(name: "lockup-black", title: "虎符输入法 Hufu 黑色横向组合",
            markColor: black, textColor: black, background: nil, rectRadius: 0),
    Variant(name: "lockup-white", title: "虎符输入法 Hufu 白色横向组合",
            markColor: white, textColor: white, background: nil, rectRadius: 0),
    Variant(name: "lockup-reversed", title: "虎符输入法 Hufu 黑底白标矩形组合",
            markColor: white, textColor: white, background: ink, rectRadius: 22)
]

let markPath = cgPath(tokensMarkPath)
let latinCMPaths = latinPaths.map(cgPath)

// Ink metrics: stroke each path with the same round cap/join used for rendering,
// then report per-letter bounds and the ink-to-ink gaps at mid-body (y=44) and
// x-height top (y=28). The f crossbar dominates the latter.
func inkBounds(_ path: CGPath) -> CGRect {
    path.copy(strokingWithWidth: strokeWidth, lineCap: .round, lineJoin: .round, miterLimit: 10)
        .boundingBoxOfPath
}

func horizontalInkRange(_ path: CGPath, at y: CGFloat) -> (minX: CGFloat, maxX: CGFloat)? {
    var intersections: [CGFloat] = []
    var current = CGPoint.zero
    func addLine(_ a: CGPoint, _ b: CGPoint) {
        guard y >= min(a.y, b.y), y <= max(a.y, b.y) else { return }
        if abs(b.y - a.y) < 1e-6 {
            intersections.append(a.x)
            intersections.append(b.x)
        } else {
            let t = (y - a.y) / (b.y - a.y)
            intersections.append(a.x + t * (b.x - a.x))
        }
    }
    func addQuad(_ a: CGPoint, _ control: CGPoint, _ b: CGPoint) {
        let qa = a.y - 2 * control.y + b.y
        let qb = 2 * (control.y - a.y)
        let qc = a.y - y
        var roots: [CGFloat] = []
        if abs(qa) < 1e-9 {
            if abs(qb) > 1e-9 { roots.append(-qc / qb) }
        } else {
            let discriminant = qb * qb - 4 * qa * qc
            if discriminant >= 0 {
                let root = sqrt(discriminant)
                roots.append((-qb + root) / (2 * qa))
                roots.append((-qb - root) / (2 * qa))
            }
        }
        for t in roots where t >= 0 && t <= 1 {
            let mt = 1 - t
            intersections.append(mt * mt * a.x + 2 * mt * t * control.x + t * t * b.x)
        }
    }
    path.applyWithBlock { element in
        let e = element.pointee
        switch e.type {
        case .moveToPoint:
            current = e.points[0]
        case .addLineToPoint:
            addLine(current, e.points[0])
            current = e.points[0]
        case .addQuadCurveToPoint:
            addQuad(current, e.points[0], e.points[1])
            current = e.points[1]
        case .addCurveToPoint:
            // The Latin wordmark uses lines and quadratics; sample cubics defensively.
            let start = current, c1 = e.points[0], c2 = e.points[1], end = e.points[2]
            for step in 0...200 {
                let t = CGFloat(step) / 200, mt = 1 - t
                let py = mt * mt * mt * start.y + 3 * mt * mt * t * c1.y + 3 * mt * t * t * c2.y + t * t * t * end.y
                if abs(py - y) < 0.05 {
                    intersections.append(mt * mt * mt * start.x + 3 * mt * mt * t * c1.x + 3 * mt * t * t * c2.x + t * t * t * end.x)
                }
            }
            current = end
        case .closeSubpath:
            break
        @unknown default:
            break
        }
    }
    guard let minX = intersections.min(), let maxX = intersections.max() else { return nil }
    return (minX - strokeWidth / 2, maxX + strokeWidth / 2)
}

let letterNames = ["H", "u", "f", "u"]
for (index, path) in latinCMPaths.enumerated() {
    let bounds = inkBounds(path)
    print(String(format: "%@ ink x %.2f..%.2f  y %.2f..%.2f",
                 letterNames[index], bounds.minX, bounds.maxX, bounds.minY, bounds.maxY))
}
let midRanges = latinCMPaths.compactMap { horizontalInkRange($0, at: 44) }
let topRanges = latinCMPaths.compactMap { horizontalInkRange($0, at: 28) }
print(String(format: "f ink at y=44 x %.2f..%.2f, at y=28 x %.2f..%.2f",
             midRanges[2].minX, midRanges[2].maxX, topRanges[2].minX, topRanges[2].maxX))
let midGaps = [
    midRanges[1].minX - midRanges[0].maxX,
    midRanges[2].minX - midRanges[1].maxX,
    midRanges[3].minX - midRanges[2].maxX
]
let topGaps = [
    topRanges[1].minX - topRanges[0].maxX,
    topRanges[2].minX - topRanges[1].maxX,
    topRanges[3].minX - topRanges[2].maxX
]
print(String(format: "gaps mid-body  H→u %.2f  u→f %.2f  f→u %.2f", midGaps[0], midGaps[1], midGaps[2]))
print(String(format: "gaps x-height  H→u %.2f  u→f %.2f  f→u %.2f", topGaps[0], topGaps[1], topGaps[2]))
let primaryGaps = [midGaps[0], midGaps[1], topGaps[2]]
print(String(format: "primary visual gaps: %.2f, %.2f, %.2f (spread %.2f)",
             primaryGaps[0], primaryGaps[1], primaryGaps[2],
             primaryGaps.max()! - primaryGaps.min()!))

func draw(_ context: CGContext, variant: Variant) {
    if let background = variant.background {
        let rect = CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight)
        context.addPath(CGPath(roundedRect: rect, cornerWidth: variant.rectRadius,
                               cornerHeight: variant.rectRadius, transform: nil))
        context.setFillColor(srgb(background))
        context.fillPath()
    }
    context.saveGState()
    context.translateBy(x: markOrigin.x, y: markOrigin.y)
    context.scaleBy(x: markScale, y: markScale)
    context.addPath(markPath)
    context.setFillColor(srgb(variant.markColor))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.translateBy(x: latinOrigin.x, y: latinOrigin.y)
    context.scaleBy(x: latinScale, y: latinScale)
    context.setStrokeColor(srgb(variant.textColor))
    context.setLineWidth(strokeWidth)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    for path in latinCMPaths {
        context.addPath(path)
        context.strokePath()
    }
    context.restoreGState()

    context.saveGState()
    context.translateBy(x: nameOrigin.x, y: nameOrigin.y)
    context.addPath(namePath)
    context.setFillColor(srgb(variant.textColor))
    context.fillPath()
    context.restoreGState()
}

// MARK: - PNG (2x) with origin metadata

func withOrigin(_ data: Data, source: String) -> Data {
    let origin = "impeccable:prompt\u{0}Origin: assets/brand/hufu/base-v1/\(source), generated by scripts/gen-lockup.swift from tokens.json and the pinned Noto Sans SC outlines."
    var payload = Data("tEXt".utf8)
    payload.append(Data(origin.utf8))
    var crc: UInt32 = 0xFFFFFFFF
    for byte in payload {
        crc ^= UInt32(byte)
        for _ in 0..<8 { crc = (crc >> 1) ^ (crc & 1 == 1 ? 0xEDB88320 : 0) }
    }
    func bigEndian(_ value: UInt32) -> Data {
        var value = value.bigEndian
        return withUnsafeBytes(of: &value) { Data($0) }
    }
    var output = Data(data.dropLast(12))
    output.append(bigEndian(UInt32(payload.count - 4)))
    output.append(payload)
    output.append(bigEndian(crc ^ 0xFFFFFFFF))
    output.append(data.suffix(12))
    return output
}

func renderPNG(_ variant: Variant) -> Data {
    let scale = 2
    let context = CGContext(data: nil, width: Int(canvasWidth) * scale, height: Int(canvasHeight) * scale,
                            bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setAllowsAntialiasing(true)
    context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
    // SVG coordinates: origin top-left, y grows downwards.
    context.translateBy(x: 0, y: canvasHeight)
    context.scaleBy(x: 1, y: -1)
    draw(context, variant: variant)
    let image = context.makeImage()!
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    precondition(CGImageDestinationFinalize(destination), "PNG encode failed")
    return data as Data
}

// MARK: - SVG

func svg(_ variant: Variant) -> String {
    var body = ""
    if let background = variant.background {
        body += #"<rect x="0" y="0" width="\#(Int(canvasWidth))" height="\#(Int(canvasHeight))" rx="\#(Int(variant.rectRadius))" fill="\#(background)"/>"#
    }
    body += #"<path data-mark-id="bookmark-v1" transform="translate(\#(Int(markOrigin.x)) \#(Int(markOrigin.y))) scale(\#(markScale))" fill="\#(variant.markColor)" d="\#(tokensMarkPath)"/>"#
    body += #"<g aria-label="Hufu" transform="translate(\#(Int(latinOrigin.x)) \#(Int(latinOrigin.y))) scale(\#(latinScale))" fill="none" stroke="\#(variant.textColor)" stroke-width="\#(Int(strokeWidth))" stroke-linecap="round" stroke-linejoin="round">"#
    body += latinPaths.map { #"<path d="\#($0)"/>"# }.joined()
    body += "</g>"
    body += #"<path aria-label="\#(nameText)" transform="translate(\#(Int(nameOrigin.x)) \#(Int(nameOrigin.y)))" fill="\#(variant.textColor)" d="\#(nameD)"/>"#
    return #"<svg xmlns="http://www.w3.org/2000/svg" width="\#(Int(canvasWidth))" height="\#(Int(canvasHeight))" viewBox="0 0 \#(Int(canvasWidth)) \#(Int(canvasHeight))" role="img"><title>\#(variant.title)</title>\#(body)</svg>"# + "\n"
}

// MARK: - Write artwork

for variant in variants {
    try svg(variant).write(to: base.appendingPathComponent(variant.name + ".svg"),
                           atomically: true, encoding: .utf8)
    let png = withOrigin(renderPNG(variant), source: variant.name + ".svg")
    try png.write(to: base.appendingPathComponent(variant.name + ".png"))
}

// MARK: - tokens.json (keep the hand-formatted layout)

let tokensURL = base.appendingPathComponent("tokens.json")
var tokensText = try String(contentsOf: tokensURL, encoding: .utf8)
if let keyRange = tokensText.range(of: #""paths": ["#) ?? tokensText.range(of: #""paths":["#) {
    guard let end = tokensText[keyRange.upperBound...].firstIndex(of: "]") else { fatalError("unterminated tokens paths") }
    let replacement = latinPaths.map { #""\#($0)""# }.joined(separator: ", ")
    tokensText.replaceSubrange(keyRange.upperBound..<end, with: replacement)
} else {
    fatalError("tokens.json has no latinWordmark paths")
}
try tokensText.write(to: tokensURL, atomically: true, encoding: .utf8)

// MARK: - type-outlines.json (replace only the name record)

let outlinesURL = base.appendingPathComponent("type-outlines.json")
guard var outlines = try JSONSerialization.jsonObject(with: Data(contentsOf: outlinesURL)) as? [String: Any] else {
    fatalError("type-outlines.json is not an object")
}
outlines["name"] = [
    "text": nameText,
    "size": nameSize,
    "weight": nameWeight,
    "tracking": nameTracking,
    "width": nameWidth,
    "d": nameD,
    "postScriptName": CTFontCopyPostScriptName(nameFont) as String,
    "variation": [["axis": 0x7767_6874, "value": nameWeight]]
] as [String: Any]
let outlinesData = try JSONSerialization.data(withJSONObject: outlines, options: [.sortedKeys, .prettyPrinted])
try outlinesData.write(to: outlinesURL)

// MARK: - manifest.json (refresh bytes/sha256 for the files this script owns)

let manifestURL = base.appendingPathComponent("manifest.json")
var manifestText = try String(contentsOf: manifestURL, encoding: .utf8)
let owned = variants.flatMap { [$0.name + ".svg", $0.name + ".png"] } + ["tokens.json", "type-outlines.json"]
for path in owned {
    let fileData = try Data(contentsOf: base.appendingPathComponent(path))
    let fileDigest = SHA256.hash(data: fileData).map { String(format: "%02x", $0) }.joined()
    let pattern = #"("path"\s*:\s*"\#(NSRegularExpression.escapedPattern(for: path))"\s*,\s*"bytes"\s*:\s*)\d+(\s*,\s*"sha256"\s*:\s*")[0-9a-f]{64}(")"#
    let expression = try NSRegularExpression(pattern: pattern)
    let range = NSRange(manifestText.startIndex..., in: manifestText)
    let count = expression.numberOfMatches(in: manifestText, range: range)
    guard count == 1, let match = expression.firstMatch(in: manifestText, range: range) else {
        fatalError("manifest.json entry missing or duplicated: \(path)")
    }
    let text = manifestText as NSString
    let replacement = text.substring(with: match.range(at: 1))
        + "\(fileData.count)"
        + text.substring(with: match.range(at: 2))
        + fileDigest
        + text.substring(with: match.range(at: 3))
    manifestText = text.replacingCharacters(in: match.range, with: replacement)
}
try manifestText.write(to: manifestURL, atomically: true, encoding: .utf8)

print("lockups written: \(variants.map(\.name).joined(separator: ", "))")
print("latin paths: \(latinPaths.count), name outline: \(nameText) \(Int(nameSize))pt w\(Int(nameWeight))")
