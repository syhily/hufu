import AppKit
import InputMethodKit

// Hufu input method server. Runs as a background agent (LSUIElement) launched by the
// system's text input machinery; InputMethodKit instantiates HufuInputController per
// client context.
// Installer entry points (run by the .pkg postinstall script or scripts/install-dev.sh).
let arguments = CommandLine.arguments
if arguments.contains("--install") || arguments.contains("--enable") {
    exit(InputSourceInstaller.install(select: arguments.contains("--install")))
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate

guard let connectionName = Bundle.main.object(forInfoDictionaryKey: "InputMethodConnectionName") as? String,
      let server = IMKServer(name: connectionName, bundleIdentifier: Bundle.main.bundleIdentifier) else {
    fatalError("Hufu: failed to start IMKServer")
}
delegate.server = server
application.run()
