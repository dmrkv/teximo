import Cocoa

if CommandLine.arguments.contains("--version") {
    print(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Teximo (development)")
    exit(0)
}

let app = NSApplication.shared
// AppKit's application entry point runs on the main thread.
let delegate = MainActor.assumeIsolated { SimpleAppDelegate() }
app.delegate = delegate
app.run()
