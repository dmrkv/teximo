#!/usr/bin/env swift

import Cocoa

print("=== SIMPLE TEST STARTING ===")

// Write to file immediately
let logPath = "/tmp/teximo_debug.log"
let logMessage = "[Teximo] Simple test starting\n"
try? logMessage.write(toFile: logPath, atomically: true, encoding: .utf8)

let app = NSApplication.shared
app.setActivationPolicy(.regular)

// Create a simple window
let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                      styleMask: [.titled, .closable],
                      backing: .buffered,
                      defer: false)
window.title = "Teximo Test"
window.center()
window.makeKeyAndOrderFront(nil)

// Create a label
let label = NSTextField(labelWithString: "Teximo is working!")
label.frame = NSRect(x: 50, y: 100, width: 300, height: 50)
label.font = NSFont.systemFont(ofSize: 24)
window.contentView?.addSubview(label)

// Create a button
let button = NSButton(frame: NSRect(x: 150, y: 50, width: 100, height: 30))
button.title = "Test Button"
button.target = nil
button.action = #selector(NSApplication.terminate(_:))
window.contentView?.addSubview(button)

app.activate(ignoringOtherApps: true)

print("=== SIMPLE TEST RUNNING ===")
app.run()
