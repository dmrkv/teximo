import Cocoa
import ServiceManagement

class SimpleAppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let statusMenu = NSMenu()
    private var eventMonitor: Any?
    private var transliterationTimer: Timer?
    private var isSelectingText = false
    private var permissionWindow: AccessibilityPermissionWindow?
    
    // Track modifier state to detect releases
    private var previousFlags: NSEvent.ModifierFlags = []
    private var wasLayoutSwitchPressed = false
    private var wasTransliterationPressed = false
    private var wasCaseTogglePressed = false
    
    // Track press times for release-based triggers
    private var transliterationPressTime: Date?
    private var caseTogglePressTime: Date?
    
    // Track selection activity to avoid triggering after selection
    private var lastSelectionChangeTime: Date = Date.distantPast
    private var lastKnownSelection: String = ""
    private var lastArrowKeyTime: Date = Date.distantPast
    
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
        
        // Clear existing menu to prevent duplicates
        statusMenu.removeAllItems()
        
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

        // Show current shortcuts (non-clickable info items)
        let layoutShortcut = TeximoSettings.shared.layoutSwitchHotkey.displayString
        let layoutItem = NSMenuItem(title: "Switch Layout: \(layoutShortcut)", action: nil, keyEquivalent: "")
        layoutItem.isEnabled = false
        statusMenu.addItem(layoutItem)
        
        let translitShortcut = TeximoSettings.shared.transliterationHotkey.displayString
        let translitItem = NSMenuItem(title: "Transliterate Text: \(translitShortcut)", action: nil, keyEquivalent: "")
        translitItem.isEnabled = false
        statusMenu.addItem(translitItem)
        
        let caseShortcut = TeximoSettings.shared.caseToggleHotkey.displayString
        let caseItem = NSMenuItem(title: "Toggle Case: \(caseShortcut)", action: nil, keyEquivalent: "")
        caseItem.isEnabled = false
        statusMenu.addItem(caseItem)
        
        statusMenu.addItem(NSMenuItem.separator())

        // Get app version
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let buildNumber = Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 86400) / 100
        let versionItem = NSMenuItem(title: String(format: "Teximo v%@.%d", version, Int(buildNumber)), action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        statusMenu.addItem(versionItem)
        
        statusMenu.addItem(NSMenuItem.separator())
        
        // Add Settings button (replaces Configure Shortcuts)
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = [.command]
        settingsItem.target = self
        statusMenu.addItem(settingsItem)
        
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
        
        // Also monitor mouse events to detect selection activity
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged, .rightMouseDragged]) { [weak self] _ in
            self?.lastSelectionChangeTime = Date()
        }
        
        if eventMonitor != nil {
            print("[Teximo] Global event monitor created")
        } else {
            print("[Teximo] Failed to create global event monitor")
        }
    }
    
    private func handleFlagsChanged(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        
        // Get current hotkey configurations
        let settings = TeximoSettings.shared
        
        // Check for layout switch hotkey
        let isLayoutSwitchPressed = settings.layoutSwitchHotkey.matches(flags)
        if !wasLayoutSwitchPressed && isLayoutSwitchPressed {
            // Layout switch just pressed - trigger immediately
            print("[Teximo] Layout switch hotkey detected")
            let logPath = "/tmp/teximo_debug.log"
            let logMessage = "[Teximo] Layout switch hotkey detected\n"
            try? logMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
            switchLayout()
        }
        wasLayoutSwitchPressed = isLayoutSwitchPressed
        
        // Check for transliteration hotkey - trigger on RELEASE
        let isTransliterationPressed = settings.transliterationHotkey.matches(flags)
        if !wasTransliterationPressed && isTransliterationPressed {
            // Transliteration hotkey just pressed - record time
            transliterationPressTime = Date()
            print("[Teximo] Transliteration hotkey PRESSED")
            let logPath = "/tmp/teximo_debug.log"
            let logMessage = "[Teximo] Transliteration hotkey PRESSED\n"
            try? logMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
        }
        if wasTransliterationPressed && !isTransliterationPressed {
            // Transliteration hotkey released
            print("[Teximo] Transliteration hotkey RELEASED")
            let logPath = "/tmp/teximo_debug.log"
            let logMessage = "[Teximo] Transliteration hotkey RELEASED\n"
            try? logMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
            
            if let pressTime = transliterationPressTime {
                let holdDuration = Date().timeIntervalSince(pressTime)
                transliterationPressTime = nil
                
                let timeSinceSelection = Date().timeIntervalSince(lastSelectionChangeTime)
                let timeSinceArrow = Date().timeIntervalSince(lastArrowKeyTime)
                
                print("[Teximo] Transliteration release: hold=\(holdDuration)s, sinceSelection=\(timeSinceSelection)s")
                
                if holdDuration < 0.5 && timeSinceSelection > 0.3 && timeSinceArrow > 0.3 {
                    print("[Teximo] Triggering transliteration")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                        self?.checkAndTransliterateSelectedText()
                    }
                }
            }
        }
        wasTransliterationPressed = isTransliterationPressed
        
        // Check for case toggle hotkey - trigger on RELEASE
        let isCaseTogglePressed = settings.caseToggleHotkey.matches(flags)
        if !wasCaseTogglePressed && isCaseTogglePressed {
            // Case toggle hotkey just pressed - record time
            caseTogglePressTime = Date()
            print("[Teximo] Case toggle hotkey PRESSED")
        }
        if wasCaseTogglePressed && !isCaseTogglePressed {
            // Case toggle hotkey released
            print("[Teximo] Case toggle hotkey RELEASED")
            
            if let pressTime = caseTogglePressTime {
                let holdDuration = Date().timeIntervalSince(pressTime)
                caseTogglePressTime = nil
                
                let timeSinceSelection = Date().timeIntervalSince(lastSelectionChangeTime)
                let timeSinceArrow = Date().timeIntervalSince(lastArrowKeyTime)
                
                if holdDuration < 0.5 && timeSinceSelection > 0.3 && timeSinceArrow > 0.3 {
                    print("[Teximo] Triggering case toggle")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                        self?.toggleCaseOfSelectedText()
                    }
                }
            }
        }
        wasCaseTogglePressed = isCaseTogglePressed
        
        // Update previous flags
        previousFlags = flags
    }
    
    private func handleKeyDown(_ event: NSEvent) {
        // Track arrow keys to detect text selection activity
        let arrowKeyCodes: [CGKeyCode] = [123, 124, 125, 126] // Left, Right, Down, Up
        if arrowKeyCodes.contains(CGKeyCode(event.keyCode)) {
            lastArrowKeyTime = Date()
            // If modifiers are held, user is likely selecting text
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags.contains(.shift) || flags.contains(.option) {
                lastSelectionChangeTime = Date()
            }
        }
    }
    
    private func checkAndTransliterateSelectedText() {
        print("[Teximo] Checking for selected text before transliteration")
        
        // Small delay to ensure selection is complete after modifier release
        usleep(100_000) // 100ms
        
        // Try Accessibility API first (no clipboard)
        var selectedText: String? = AccessibilityHelper.getSelectedText()
        var usedMethod = "Accessibility API"
        
        if selectedText == nil || selectedText!.isEmpty {
            // Fallback: Use clipboard to READ text (will be restored immediately)
            selectedText = getSelectedTextViaClipboard()
            usedMethod = "Clipboard"
            
            guard let text = selectedText, !text.isEmpty else {
                print("[Teximo] No text selected - skipping transliteration")
                return
            }
        }
        
        guard let text = selectedText, !text.isEmpty else {
            print("[Teximo] No text selected - doing nothing")
            return
        }
        
        // Check if selection changed recently (indicating active selection)
        if text == lastKnownSelection {
            let timeSinceChange = Date().timeIntervalSince(lastSelectionChangeTime)
            if timeSinceChange < 0.5 {
                print("[Teximo] Selection just changed - skipping transliteration")
                return
            }
        }
        lastKnownSelection = text
        lastSelectionChangeTime = Date()
        
        // Only skip if the text is very short (likely not selected text)
        if text.count < 2 {
            print("[Teximo] Text too short - doing nothing")
            return
        }
        
        print("[Teximo] Selected text found: '\(text)' - proceeding with transliteration")
        
        // Ready to transliterate
        
        // Proceed with transliteration (uses keyboard simulation to replace)
        transliterateSelectedText(selectedText: text)
    }
    
    // Get selected text via clipboard (with immediate restoration)
    private func getSelectedTextViaClipboard() -> String? {
        let pasteboard = NSPasteboard.general
        
        // Save original clipboard
        let originalClipboard = pasteboard.string(forType: .string) ?? ""
        print("[Teximo] Saved original clipboard, using Cmd+C fallback")
        
        // Ensure modifiers are cleared
        var attempts = 0
        while attempts < 10 {
            let flags = CGEventSource.flagsState(.combinedSessionState)
            if !flags.contains(.maskCommand) && !flags.contains(.maskShift) && 
               !flags.contains(.maskAlternate) && !flags.contains(.maskControl) {
                break
            }
            usleep(20_000) // 20ms
            attempts += 1
        }
        usleep(100_000) // Increased to 100ms delay
        
        // Clear clipboard first to ensure we get fresh content
        pasteboard.clearContents()
        usleep(50_000)
        
        // Send Cmd+C
        AccessibilityHelper.performKeystroke(keyCode: 8, flags: .maskCommand)
        usleep(300_000) // Increased to 300ms wait for copy to complete
        
        // Read from clipboard
        let selectedText = pasteboard.string(forType: .string)
        
        // IMMEDIATELY restore original clipboard
        pasteboard.clearContents()
        pasteboard.setString(originalClipboard, forType: .string)
        
        print("[Teximo] Read text via clipboard (now restored): '\(selectedText ?? "")'")
        
        // Verify it's different from original (actually selected text)
        if let text = selectedText, !text.isEmpty, text != originalClipboard {
            return text
        }
        
        return nil
    }
    
    private func switchLayout() {
        print("[Teximo] Switching keyboard layout using TISSelectInputSource (silent)")
        DispatchQueue.main.async {
            SimpleLayoutSwitcher.switchLayout()
        }
    }
    
    private func transliterateSelectedText(selectedText: String) {
        print("[Teximo] Transliterating selected text")
        print("[Teximo] Selected text: '\(selectedText)'")
        
        // Transliterate the text
        let transliteratedText = Transliterator.transliterate(selectedText)
        print("[Teximo] Transliterated text: '\(transliteratedText)'")
        
        // Replace selected text with transliteration
        let success = AccessibilityHelper.replaceSelectedText(with: transliteratedText)
        
        if success {
            print("[Teximo] Text replacement completed")
        } else {
            print("[Teximo] Text replacement failed")
        }
    }
    
    private func toggleCaseOfSelectedText() {
        print("[Teximo] Toggling case of selected text")
        
        // Small delay to ensure selection is complete after modifier release
        usleep(100_000) // 100ms
        
        // Try Accessibility API first (no clipboard)
        var selectedText: String? = AccessibilityHelper.getSelectedText()
        
        if selectedText == nil || selectedText!.isEmpty {
            // Fallback: Use clipboard to READ text (will be restored immediately)
            selectedText = getSelectedTextViaClipboard()
            
            guard let text = selectedText, !text.isEmpty else {
                print("[Teximo] No text selected - skipping case toggle")
                return
            }
        }
        
        guard let text = selectedText, !text.isEmpty else {
            print("[Teximo] No text selected - doing nothing")
            return
        }
        
        // Only process if the text has letters
        if text.count < 1 {
            print("[Teximo] Text too short - doing nothing")
            return
        }
        
        print("[Teximo] Selected text found: '\(text)' - proceeding with case toggle")
        
        // Transform case
        let transformedText = CaseToggle.transform(text)
        print("[Teximo] Transformed text: '\(transformedText)'")
        
        // Replace selected text with transformed version
        let success = AccessibilityHelper.replaceSelectedText(with: transformedText)
        
        if success {
            print("[Teximo] Case toggle completed")
        } else {
            print("[Teximo] Case toggle failed")
        }
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
        
        // Check accessibility permissions first
        let hasAccessibility = AccessibilityHelper.ensurePermission(promptIfNeeded: true)
        print("[Teximo] Accessibility permission: \(hasAccessibility)")
        
        if hasAccessibility {
            // Only use Accessibility API (no clipboard)
            if let selectedText = AccessibilityHelper.getSelectedText(), !selectedText.isEmpty {
                transliterateSelectedText(selectedText: selectedText)
            } else {
                print("[Teximo] No text selected for transliteration")
            }
        } else {
            print("[Teximo] No accessibility permission, cannot transliterate text")
        }
    }
    
    
    // MARK: - Layout Selection Menu Helpers
    
    private func getCurrentEnglishLayoutName() -> String {
        TeximoSettings.shared.selectedLayout1?.displayName ?? "Auto"
    }
    
    private func getCurrentRussianLayoutName() -> String {
        TeximoSettings.shared.selectedLayout2?.displayName ?? "Auto"
    }
    
    private func populateEnglishLayoutMenu(_ menu: NSMenu) {
        // Add "Auto" option
        let autoItem = NSMenuItem(title: "Auto (detect)", action: #selector(selectEnglishLayout(_:)), keyEquivalent: "")
        autoItem.target = self
        autoItem.representedObject = nil
        if TeximoSettings.shared.selectedLayout1 == nil {
            autoItem.state = .on
        }
        menu.addItem(autoItem)
        menu.addItem(NSMenuItem.separator())
        
        // Get English layouts only
        DispatchQueue.main.async {
            let englishLayouts = LayoutEnumerator.getEnglishLayouts()
            for layout in englishLayouts {
                let item = NSMenuItem(title: layout.displayName, action: #selector(self.selectEnglishLayout(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = layout
                if TeximoSettings.shared.selectedLayout1?.sourceID == layout.sourceID {
                    item.state = .on
                }
                menu.addItem(item)
            }
        }
    }
    
    private func populateRussianLayoutMenu(_ menu: NSMenu) {
        // Add "Auto" option
        let autoItem = NSMenuItem(title: "Auto (detect)", action: #selector(selectRussianLayout(_:)), keyEquivalent: "")
        autoItem.target = self
        autoItem.representedObject = nil
        if TeximoSettings.shared.selectedLayout2 == nil {
            autoItem.state = .on
        }
        menu.addItem(autoItem)
        menu.addItem(NSMenuItem.separator())
        
        // Get Russian layouts only
        DispatchQueue.main.async {
            let russianLayouts = LayoutEnumerator.getRussianLayouts()
            for layout in russianLayouts {
                let item = NSMenuItem(title: layout.displayName, action: #selector(self.selectRussianLayout(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = layout
                if TeximoSettings.shared.selectedLayout2?.sourceID == layout.sourceID {
                    item.state = .on
                }
                menu.addItem(item)
            }
        }
    }
    
    @objc private func selectEnglishLayout(_ sender: NSMenuItem) {
        let layout = sender.representedObject as? KeyboardLayout
        TeximoSettings.shared.selectedLayout1 = layout
        print("[Teximo] Selected English layout: \(layout?.displayName ?? "Auto")")
        
        // Update checkmarks in this menu
        sender.menu?.items.forEach { $0.state = .off }
        sender.state = .on
        
        // Update parent menu title
        if let parentItem = sender.menu?.supermenu?.items.first(where: { $0.submenu == sender.menu }) {
            parentItem.title = "  English: \(layout?.displayName ?? "Auto")"
        }
    }
    
    @objc private func selectRussianLayout(_ sender: NSMenuItem) {
        let layout = sender.representedObject as? KeyboardLayout
        TeximoSettings.shared.selectedLayout2 = layout
        print("[Teximo] Selected Russian layout: \(layout?.displayName ?? "Auto")")
        
        // Update checkmarks in this menu
        sender.menu?.items.forEach { $0.state = .off }
        sender.state = .on
        
        // Update parent menu title
        if let parentItem = sender.menu?.supermenu?.items.first(where: { $0.submenu == sender.menu }) {
            parentItem.title = "  Russian: \(layout?.displayName ?? "Auto")"
        }
    }
    
    @objc private func openSettings() {
        let settingsWindow = SettingsWindow()
        settingsWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
