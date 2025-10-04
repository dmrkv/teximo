import Cocoa
import ServiceManagement

class SimpleAppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let statusMenu = NSMenu()
    private var eventMonitor: Any?
    private var transliterationTimer: Timer?
    private var isSelectingText = false
    private var permissionWindow: AccessibilityPermissionWindow?
    
    override init() {
        super.init()
        print("[Teximo] SimpleAppDelegate init called")
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[Teximo] SimpleAppDelegate applicationDidFinishLaunching - START")
        NSApp.setActivationPolicy(.accessory)
        
        setupStatusItem()
        
        // Check accessibility permissions first
        if !AccessibilityHelper.ensurePermission(promptIfNeeded: false) {
            print("[Teximo] No accessibility permission, showing permission window")
            showAccessibilityPermissionWindow()
        } else {
            print("[Teximo] Accessibility permission granted, setting up hotkeys")
            setupHotkeyDetection()
        }
        
        print("[Teximo] SimpleAppDelegate applicationDidFinishLaunching - END")
    }
    
    private func setupStatusItem() {
        print("[Teximo] Creating status item…")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                if let button = statusItem.button {
                    print("[Teximo] Status button created")
                    button.title = ""
                    print("[Teximo] Button title cleared")
                    if let img = IconGenerator.createMenuBarIcon() {
                        button.image = img
                        print("[Teximo] Custom T icon set")
                    } else {
                        print("[Teximo] Failed to create custom icon, using fallback")
                        button.title = "T"
                    }
                }
        print("[Teximo] Status item set up")

        let switchItem = NSMenuItem(title: "Switch Layout", action: #selector(testLayoutSwitch), keyEquivalent: "⇧")
        switchItem.keyEquivalentModifierMask = [.command]
        switchItem.target = self
        statusMenu.addItem(switchItem)
        
        let transliterationItem = NSMenuItem(title: "Transliterate Text", action: #selector(testTransliteration), keyEquivalent: "⇧")
        transliterationItem.keyEquivalentModifierMask = [.control]
        transliterationItem.target = self
        statusMenu.addItem(transliterationItem)
        statusMenu.addItem(NSMenuItem.separator())

        // Get app version
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let aboutItem = NSMenuItem(title: "Teximo v\(version)", action: nil, keyEquivalent: "")
        aboutItem.isEnabled = false
        statusMenu.addItem(aboutItem)
        
        // Add startup checkbox
        let startupItem = NSMenuItem(title: "Start Teximo when macOS starts", action: #selector(toggleStartup), keyEquivalent: "")
        startupItem.target = self
        startupItem.state = isStartupEnabled() ? .on : .off
        statusMenu.addItem(startupItem)
        
        statusMenu.addItem(NSMenuItem.separator())
        statusMenu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = statusMenu
        print("[Teximo] Status menu assigned")
    }
    
    private func setupHotkeyDetection() {
        print("[Teximo] Setting up hotkey detection")
        
        // Use NSEvent monitors for global hotkey detection
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            if event.type == .flagsChanged {
                self?.handleFlagsChanged(event)
            } else if event.type == .keyDown {
                self?.handleKeyDown(event)
            }
        }
        
        if eventMonitor != nil {
            print("[Teximo] Global event monitor created")
        } else {
            print("[Teximo] Failed to create global event monitor")
        }
    }
    
            private func handleFlagsChanged(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hasShift = flags.contains(.shift)
        let hasCmd = flags.contains(.command)
        let hasOption = flags.contains(.option)
        let hasControl = flags.contains(.control)
        
        // Check for Cmd+Shift combination (layout switching)
        if hasShift && hasCmd {
            print("[Teximo] Cmd+Shift detected via hotkey")
            let logPath = "/tmp/teximo_debug.log"
            let logMessage = "[Teximo] Cmd+Shift detected via hotkey\n"
            try? logMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
            
            // Trigger layout switch
            switchLayout()
        }
        // Check for Control+Shift combination (transliteration)
        else if hasShift && hasControl {
            print("[Teximo] Control+Shift detected via hotkey")
            let logPath = "/tmp/teximo_debug.log"
            let logMessage = "[Teximo] Control+Shift detected via hotkey\n"
            try? logMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
            
            // Trigger transliteration
            checkAndTransliterateSelectedText()
        }
        // If neither Control+Shift nor Cmd+Shift, cancel any pending transliteration
        else {
            transliterationTimer?.invalidate()
            transliterationTimer = nil
        }
    }
    
    private func handleKeyDown(_ event: NSEvent) {
        // No longer needed - using Ctrl+Shift instead of Option+Shift+T
        // This method is kept for potential future use
    }
    
    private func checkAndTransliterateSelectedText() {
        print("[Teximo] Checking for selected text before transliteration")
        let logPath = "/tmp/teximo_debug.log"
        let logMessage = "[Teximo] Checking for selected text before transliteration\n"
        try? logMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
        
        // Save current clipboard content
        let pasteboard = NSPasteboard.general
        let originalClipboard = pasteboard.string(forType: .string) ?? ""
        
        // Copy selected text to clipboard
        AccessibilityHelper.performKeystroke(keyCode: 8, flags: .maskCommand) // Cmd+C
        usleep(150_000) // Wait 150ms for copy to complete
        
        // Get the selected text from clipboard
        guard let selectedText = pasteboard.string(forType: .string), !selectedText.isEmpty else {
            print("[Teximo] No text selected - doing nothing")
            let noTextMessage = "[Teximo] No text selected - doing nothing\n"
            try? noTextMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
            
            // Restore original clipboard
            pasteboard.clearContents()
            pasteboard.setString(originalClipboard, forType: .string)
            return
        }
        
        // If user is actively selecting text, don't transliterate
        if isSelectingText {
            print("[Teximo] User is actively selecting text - skipping transliteration")
            let selectingMessage = "[Teximo] User is actively selecting text - skipping transliteration\n"
            try? selectingMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
            return
        }
        
        // Only skip if the text is very short (likely not selected text)
        // Don't skip based on clipboard comparison - we want to allow transliteration back and forth
        if selectedText.count < 2 {
            print("[Teximo] Text too short - doing nothing")
            let tooShortMessage = "[Teximo] Text too short - doing nothing\n"
            try? tooShortMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
            return
        }
        
        print("[Teximo] Selected text found: '\(selectedText)' - proceeding with transliteration")
        let foundTextMessage = "[Teximo] Selected text found: '\(selectedText)' - proceeding with transliteration\n"
        try? foundTextMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
        
        // Proceed with transliteration
        transliterateSelectedText()
    }
    
    private func switchLayout() {
        print("[Teximo] Switching keyboard layout using Control+Space")
        
        // Use a simple approach - simulate Control+Space keystroke
        let spaceKey: CGKeyCode = 49
        
        // Create the key event
        let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: spaceKey, keyDown: true)
        let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: spaceKey, keyDown: false)
        
        // Set Control modifier
        keyDownEvent?.flags = .maskControl
        keyUpEvent?.flags = .maskControl
        
        // Post the events
        keyDownEvent?.post(tap: .cghidEventTap)
        usleep(10000) // 10ms delay
        keyUpEvent?.post(tap: .cghidEventTap)
        
        print("[Teximo] Sent Control+Space keystroke")
    }
    
    private func transliterateSelectedText() {
        print("[Teximo] Transliterating selected text")
        let logPath = "/tmp/teximo_debug.log"
        let logMessage = "[Teximo] Transliterating selected text\n"
        try? logMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
        
        // Get the selected text from clipboard (already copied by checkAndTransliterateSelectedText)
        let pasteboard = NSPasteboard.general
        guard let selectedText = pasteboard.string(forType: .string), !selectedText.isEmpty else {
            print("[Teximo] No text in clipboard - doing nothing")
            let noTextMessage = "[Teximo] No text in clipboard - doing nothing\n"
            try? noTextMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
            return
        }
        
        print("[Teximo] Selected text: '\(selectedText)'")
        let selectedMessage = "[Teximo] Selected text: '\(selectedText)'\n"
        try? selectedMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
        
        // Transliterate the text
        let transliteratedText = Transliterator.transliterate(selectedText)
        print("[Teximo] Transliterated text: '\(transliteratedText)'")
        let transliteratedMessage = "[Teximo] Transliterated text: '\(transliteratedText)'\n"
        try? transliteratedMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
        
        // Put transliterated text in clipboard
        pasteboard.clearContents()
        pasteboard.setString(transliteratedText, forType: .string)
        
        // Wait a moment for clipboard to be ready
        usleep(50_000)
        
        // Paste the transliterated text (this will replace the selected text)
        AccessibilityHelper.performKeystroke(keyCode: 9, flags: .maskCommand) // Cmd+V
        
        print("[Teximo] Text replacement completed")
        let completedMessage = "[Teximo] Text replacement completed\n"
        try? completedMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
    }
    
    @objc private func testLayoutSwitch() {
        print("[Teximo] Test layout switch triggered")
        let logPath = "/tmp/teximo_debug.log"
        let logMessage = "[Teximo] Test layout switch triggered\n"
        try? logMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
        
        // Check accessibility permissions first
        let hasAccessibility = AccessibilityHelper.ensurePermission(promptIfNeeded: true)
        print("[Teximo] Accessibility permission: \(hasAccessibility)")
        let logMessage2 = "[Teximo] Accessibility permission: \(hasAccessibility)\n"
        try? logMessage2.write(toFile: logPath, atomically: true, encoding: .utf8)
        
        if hasAccessibility {
            switchLayout()
        } else {
            print("[Teximo] No accessibility permission, cannot switch layout")
            let logMessage4 = "[Teximo] No accessibility permission, cannot switch layout\n"
            try? logMessage4.write(toFile: logPath, atomically: true, encoding: .utf8)
        }
    }
    
    @objc private func testTransliteration() {
        print("[Teximo] Test transliteration triggered")
        let logPath = "/tmp/teximo_debug.log"
        let logMessage = "[Teximo] Test transliteration triggered\n"
        try? logMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
        
        // Check accessibility permissions first
        let hasAccessibility = AccessibilityHelper.ensurePermission(promptIfNeeded: true)
        print("[Teximo] Accessibility permission: \(hasAccessibility)")
        let logMessage2 = "[Teximo] Accessibility permission: \(hasAccessibility)\n"
        try? logMessage2.write(toFile: logPath, atomically: true, encoding: .utf8)
        
        if hasAccessibility {
            transliterateSelectedText()
        } else {
            print("[Teximo] No accessibility permission, cannot transliterate text")
            let logMessage4 = "[Teximo] No accessibility permission, cannot transliterate text\n"
            try? logMessage4.write(toFile: logPath, atomically: true, encoding: .utf8)
        }
    }
    
    @objc private func quit() {
        NSApp.terminate(nil)
    }
    
    @objc private func toggleStartup() {
        let isEnabled = isStartupEnabled()
        setStartupEnabled(!isEnabled)
        
        // Update the menu item state
        if let startupItem = statusMenu.items.first(where: { $0.title.contains("Start Teximo when macOS starts") }) {
            startupItem.state = !isEnabled ? .on : .off
        }
    }
    
    private func isStartupEnabled() -> Bool {
        // Check if the app is in Login Items using AppleScript
        let script = """
        tell application "System Events"
            get the name of every login item
        end tell
        """
        
        let appleScript = NSAppleScript(source: script)
        let result = appleScript?.executeAndReturnError(nil)
        
        if let loginItems = result?.stringValue {
            return loginItems.contains("Teximo")
        }
        
        return UserDefaults.standard.bool(forKey: "TeximoStartupEnabled")
    }
    
    private func setStartupEnabled(_ enabled: Bool) {
        let appPath = Bundle.main.bundlePath
        
        if enabled {
            // Add to Login Items using AppleScript
            let script = """
            tell application "System Events"
                make login item at end with properties {path:"\(appPath)", hidden:false}
            end tell
            """
            
            let appleScript = NSAppleScript(source: script)
            let result = appleScript?.executeAndReturnError(nil)
            
            if result != nil {
                print("[Teximo] Successfully added to Login Items - app will start automatically")
            } else {
                print("[Teximo] Failed to add to Login Items")
                print("[Teximo] You may need to manually add Teximo to Login Items:")
                print("[Teximo] 1. Go to System Settings > Users & Groups > Login Items")
                print("[Teximo] 2. Click the '+' button")
                print("[Teximo] 3. Select Teximo.app from Applications folder")
            }
        } else {
            // Remove from Login Items using AppleScript
            let script = """
            tell application "System Events"
                delete login item "Teximo"
            end tell
            """
            
            let appleScript = NSAppleScript(source: script)
            let result = appleScript?.executeAndReturnError(nil)
            
            if result != nil {
                print("[Teximo] Successfully removed from Login Items - app will not start automatically")
            } else {
                print("[Teximo] Failed to remove from Login Items")
            }
        }
        
        // Store the preference for UI state
        UserDefaults.standard.set(enabled, forKey: "TeximoStartupEnabled")
    }
    
    private func showAccessibilityPermissionWindow() {
        permissionWindow = AccessibilityPermissionWindow { [weak self] in
            print("[Teximo] Accessibility permission granted, app will restart automatically")
            // The app will restart automatically, so we don't need to set up hotkeys here
            self?.permissionWindow = nil
        }
        permissionWindow?.showWindow()
    }
}
