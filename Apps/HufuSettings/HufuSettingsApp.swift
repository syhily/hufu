import HufuAI
import AppKit
import SwiftUI

@main
struct HufuSettingsApp: App {
    @NSApplicationDelegateAdaptor(SettingsAppDelegate.self) private var appDelegate
    @State private var model = SettingsModel()
    @State private var selection: Pane? = LaunchOptions.pane ?? .overview

    init() {
        // The API key used to live in the login Keychain, which made macOS ask for the
        // password when the input method read it. It now lives in an owner-only file.
        CredentialStore(account: "openai-compatible").migrateFromKeychain()
        switch LaunchOptions.argument("--appearance") {
        case "dark": NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        case "light": NSApplication.shared.appearance = NSAppearance(named: .aqua)
        default: break
        }
    }

    var body: some Scene {
        Window("虎符输入法设置", id: "main") {
            // The settings layout needs 900 × 620; onboarding sizes the window per step.
            RootView(selection: $selection)
                .environment(model)
        }
        .defaultSize(width: 1080, height: 720)
        // A settings app must always open its window: never restore a "closed" state.
        .defaultLaunchBehavior(.presented)
        .restorationBehavior(.disabled)
        .windowToolbarStyle(.unified)
        .commands {
            AboutCommands(selection: $selection)
            CommandGroup(replacing: .newItem) {}
            CommandMenu("部署") {
                Button("重新部署") { Task { await model.deploy() } }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }
    }
}

/// The standard app menu and sidebar share navigation state, including a newly opened window.
private struct AboutCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @Binding var selection: Pane?

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("关于虎符输入法") {
                selection = .about
                openWindow(id: "main")
                NSApp.activate()
            }
        }
    }
}

/// Reopens the settings window when the Dock icon is clicked with no window open,
/// and quits when the last window closes (it is a single-window utility).
final class SettingsAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { sender.windows.first { $0.canBecomeMain }?.makeKeyAndOrderFront(nil) }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
