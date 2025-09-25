import Cocoa

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
        transliterationItem.keyEquivalentModifierMask = [.option]
        transliterationItem.target = self
        statusMenu.addItem(transliterationItem)
        statusMenu.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(title: "Teximo", action: nil, keyEquivalent: "")
        aboutItem.isEnabled = false
        statusMenu.addItem(aboutItem)
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
        
        // Check for Cmd+Shift combination (layout switching)
        if hasShift && hasCmd {
            print("[Teximo] Cmd+Shift detected via hotkey")
            let logPath = "/tmp/teximo_debug.log"
            let logMessage = "[Teximo] Cmd+Shift detected via hotkey\n"
            try? logMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
            
            // Trigger layout switch
            switchLayout()
        }
        // Check for Option+Shift combination (transliteration)
        else if hasShift && hasOption {
            print("[Teximo] Option+Shift detected via hotkey")
            let logPath = "/tmp/teximo_debug.log"
            let logMessage = "[Teximo] Option+Shift detected via hotkey\n"
            try? logMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
            
            // If user is not actively selecting text, check if there's selected text to transliterate
            if !isSelectingText {
                print("[Teximo] Not selecting text, checking for selected text to transliterate")
                let notSelectingMessage = "[Teximo] Not selecting text, checking for selected text to transliterate\n"
                try? notSelectingMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
                
                // Only transliterate if there's actually selected text
                checkAndTransliterateSelectedText()
            } else {
                print("[Teximo] User is selecting text, skipping transliteration")
                let selectingMessage = "[Teximo] User is selecting text, skipping transliteration\n"
                try? selectingMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
            }
        }
        // If neither Option+Shift nor Cmd+Shift, cancel any pending transliteration
        else {
            transliterationTimer?.invalidate()
            transliterationTimer = nil
        }
    }
    
    private func handleKeyDown(_ event: NSEvent) {
        // Check if user is pressing arrow keys while holding Option+Shift (text selection)
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hasShift = flags.contains(.shift)
        let hasOption = flags.contains(.option)
        
        // Arrow key codes: 123=left, 124=right, 125=down, 126=up
        let arrowKeys: Set<UInt16> = [123, 124, 125, 126]
        
        if arrowKeys.contains(event.keyCode) && hasShift && hasOption {
            print("[Teximo] Arrow key detected with Option+Shift - user is selecting text")
            let logPath = "/tmp/teximo_debug.log"
            let logMessage = "[Teximo] Arrow key detected with Option+Shift - user is selecting text\n"
            try? logMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
            
            isSelectingText = true
            
            // Reset the flag after a longer delay to ensure selection is complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.isSelectingText = false
            }
        }
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
        let logPath = "/tmp/teximo_debug.log"
        let logMessage = "[Teximo] Switching keyboard layout using Control+Space\n"
        try? logMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
        
        // Use only Control+Space - this is the most common default shortcut
        // and won't interfere with other apps like Espanso or ChatGPT
        let spaceKey: CGKeyCode = 49
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            AccessibilityHelper.performKeystroke(keyCode: spaceKey, flags: .maskControl)
        }
        
        print("[Teximo] Sent Control+Space keystroke")
        let sentMessage = "[Teximo] Sent Control+Space keystroke\n"
        try? sentMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
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
    
    private func showAccessibilityPermissionWindow() {
        permissionWindow = AccessibilityPermissionWindow { [weak self] in
            print("[Teximo] Accessibility permission granted, setting up hotkeys")
            self?.setupHotkeyDetection()
            self?.permissionWindow = nil
        }
        permissionWindow?.showWindow()
    }
}
