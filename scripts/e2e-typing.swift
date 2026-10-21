#!/usr/bin/env swift
// End-to-end typing test: selects the Hufu input source, types into a fresh TextEdit
// document through real key events, reads back the text, then restores the previous
// input source.   swift scripts/e2e-typing.swift [keys] [expected]
//
// No arguments → runs the built-in suite: 虎码打字 + 特殊输入（/time、/date、/week、
// /cdate、=计算器、/数字大写）+ 设置开关（关闭计算器后注入消失）。每个用例一行，
// 断言支持「contains:文本」（默认）与「re:正则」。
//
// 首次使用需先在 系统设置 › 键盘 › 输入法 添加一次虎符输入法（或注销重登）；
// 这是 macOS 对输入法上架的固定要求，无法脚本绕过。
import AppKit
import Carbon
import Foundation

struct Case {
    let keys: String
    let contains: String?
    let regex: String?
    let note: String

    init(_ keys: String, _ contains: String, note: String = "") {
        self.keys = keys; self.contains = contains; self.regex = nil; self.note = note
    }
    init(keys: String, re: String, note: String = "") {
        self.keys = keys; self.contains = nil; self.regex = re; self.note = note
    }
}

let formatter = DateFormatter()
formatter.locale = Locale(identifier: "zh_CN")
formatter.dateFormat = "yyyy.MM.dd"
let today = formatter.string(from: Date())
formatter.dateFormat = "cccc"
let weekday = formatter.string(from: Date())

var cases: [Case] = [
    Case("jxbh ", "你好", note: "虎码基线"),
    Case(keys: "=1+2*3 ", re: #"1\+2\*3=7"#, note: "计算器"),
    Case("/1234 ", "一千二百三十四", note: "大写数字"),
    Case("/date ", today, note: "日期"),
    Case(keys: "/time ", re: #"\d{2}:\d{2}"#, note: "时间"),
    Case("/week ", weekday, note: "星期"),
    Case(keys: "/cdate ", re: #"农历\S+"#, note: "农历"),
]

if CommandLine.arguments.count > 2 {
    cases = [Case(CommandLine.arguments[1], CommandLine.arguments[2], note: "自定义")]
}

func sources(_ id: String) -> [TISInputSource] {
    let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
    return (TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource]) ?? []
}

let modeID = "dev.yufan.hufu.inputmethod.hans"
if sources(modeID).isEmpty {
    let install = Process()
    install.executableURL = URL(fileURLWithPath: "/Users/Yufan/Library/Input Methods/Hufu.app/Contents/MacOS/Hufu")
    install.arguments = ["--install"]
    try? install.run(); install.waitUntilExit()
    if sources(modeID).isEmpty {
        print("FAIL: 虎符输入法未出现在输入法列表。请先在 系统设置 › 键盘 › 输入法 中添加一次")
        print("     （或注销重登），再运行本脚本。这是 macOS 对输入法上架的固定要求。")
        exit(1)
    }
}

let previous = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
let hufu = sources(modeID).first!

func osa(_ script: String) -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    p.arguments = ["-e", script]
    let pipe = Pipe(); p.standardOutput = pipe; p.standardError = pipe
    try? p.run(); p.waitUntilExit()
    return String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
}

TISEnableInputSource(hufu)
_ = osa(#"tell application "TextEdit" to activate"#)
_ = osa(#"tell application "TextEdit" to make new document"#)
Thread.sleep(forTimeInterval: 1.2)
TISSelectInputSource(hufu)
// Give the system time to launch the input method process on first selection.
Thread.sleep(forTimeInterval: 3.0)

// 设置链路（features.json + 分布式通知）：先备份，结尾还原。
let featuresURL = URL(fileURLWithPath: NSHomeDirectory() + "/Library/Hufu/Rime/hufu/features.json")
let savedFeatures = try? Data(contentsOf: featuresURL)

// Key events via System Events (needs Accessibility permission for osascript);
// they go through the active input method like physical keystrokes.
// 一个用例一行；用例结束后换行即提交完成，分开调用 osascript 不会串扰。
func keystroke(_ text: String) {
    let escaped = text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    _ = osa("tell application \"System Events\" to keystroke \"\(escaped)\"")
    _ = osa("tell application \"System Events\" to key code 36")
}

for c in cases {
    keystroke(c.keys)
    Thread.sleep(forTimeInterval: 0.3)
}

// 设置链路用例：先关闭计算器开关，再输入 =1+1——注入候选应消失（不出现 =3）。
if savedFeatures != nil, var json = (try? JSONSerialization.jsonObject(with: savedFeatures ?? Data())) as? [String: Any] {
    json["calculatorCandidates"] = false
    if let data = try? JSONSerialization.data(withJSONObject: json) {
        try? data.write(to: featuresURL)
        DistributedNotificationCenter.default().postNotificationName(.init("dev.yufan.hufu.features"), object: nil)
        Thread.sleep(forTimeInterval: 1.0)
    }
    keystroke("=1+1 ")
}
Thread.sleep(forTimeInterval: 1.0)
let document = osa(#"tell application "TextEdit" to get text of front document"#)

// 恢复设置与输入法
if let savedFeatures { try? savedFeatures.write(to: featuresURL) }
DistributedNotificationCenter.default().postNotificationName(.init("dev.yufan.hufu.features"), object: nil)
TISSelectInputSource(previous)
_ = osa(#"tell application "TextEdit" to close front document saving no"#)

let lines = document.components(separatedBy: "\n")
var failures = 0
for (index, c) in cases.enumerated() {
    let got = index < lines.count ? lines[index] : ""
    let ok: Bool
    if let contains = c.contains {
        ok = got.contains(contains)
    } else {
        ok = got.range(of: c.regex ?? "", options: .regularExpression) != nil
    }
    print("\(ok ? "PASS" : "FAIL") [\(c.note)] typed \(c.keys.debugDescription) → \(got.debugDescription)")
    if !ok { failures += 1 }
}

// 设置链路断言：calculatorCandidates=false 时 =1+1 不应出现 "=3"
let toggleLine = lines.dropFirst(cases.count).first ?? ""
if savedFeatures != nil {
    let off = !toggleLine.contains("=3")
    print("\(off ? "PASS" : "FAIL") [开关关闭] =1+1 → \(toggleLine.debugDescription)")
    if !off { failures += 1 }
}

if failures > 0 { print("FAIL: \(failures) 个用例未过"); exit(1) }
print("PASS (\(cases.count + (savedFeatures != nil ? 1 : 0)) 个用例)")
