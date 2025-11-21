import Cocoa

class SettingsWindow: NSWindow {
    private var layoutSwitchButton: NSButton!
    private var transliterationButton: NSButton!
    private var caseToggleButton: NSButton!
    private var layoutSwitchWarning: NSTextField!
    private var transliterationWarning: NSTextField!
    private var caseToggleWarning: NSTextField!
    private var englishLayoutPopup: NSPopUpButton!
    private var russianLayoutPopup: NSPopUpButton!
    private var recordingFor: String? = nil
    private var previousHotkey: HotkeyConfig? = nil
    private var keyMonitor: Any?
    private var flagsMonitor: Any?
    private var lastModifiers: Set<ModifierKey> = []
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        self.title = "Settings"
        self.isReleasedWhenClosed = false
        self.center()
        setupUI()
    }
    
    private func setupUI() {
        let contentView = NSView(frame: self.contentView!.bounds)
        self.contentView = contentView
        let leftMargin = 30
        let controlX = leftMargin + 160
        let controlWidth = 280
        var yPos = 450
        
        // STARTUP AT TOP
        let startupCheckbox = NSButton(checkboxWithTitle: "Start Teximo when macOS starts", target: self, action: #selector(toggleStartup))
        startupCheckbox.frame = NSRect(x: leftMargin, y: yPos, width: 300, height: 20)
        startupCheckbox.state = isStartupEnabled() ? .on : .off
        contentView.addSubview(startupCheckbox)
        yPos -= 50
        
        // KEYBOARD LAYOUTS
        let layoutsTitle = NSTextField(labelWithString: "Keyboard Layouts")
        layoutsTitle.font = NSFont.systemFont(ofSize: 16, weight: .bold)
        layoutsTitle.frame = NSRect(x: leftMargin, y: yPos, width: 460, height: 25)
        contentView.addSubview(layoutsTitle)
        yPos -= 40
        
        let englishLabel = NSTextField(labelWithString: "English:")
        englishLabel.frame = NSRect(x: leftMargin, y: yPos, width: 120, height: 20)
        contentView.addSubview(englishLabel)
        englishLayoutPopup = NSPopUpButton(frame: NSRect(x: controlX, y: yPos - 2, width: controlWidth, height: 25))
        populateLayoutPopup(englishLayoutPopup, language: "English")
        englishLayoutPopup.target = self
        englishLayoutPopup.action = #selector(layoutSelected(_:))
        contentView.addSubview(englishLayoutPopup)
        yPos -= 35
        
        let russianLabel = NSTextField(labelWithString: "Russian:")
        russianLabel.frame = NSRect(x: leftMargin, y: yPos, width: 120, height: 20)
        contentView.addSubview(russianLabel)
        russianLayoutPopup = NSPopUpButton(frame: NSRect(x: controlX, y: yPos - 2, width: controlWidth, height: 25))
        populateLayoutPopup(russianLayoutPopup, language: "Russian")
        russianLayoutPopup.target = self
        russianLayoutPopup.action = #selector(layoutSelected(_:))
        contentView.addSubview(russianLayoutPopup)
        yPos -= 50
        
        // SHORTCUTS
        let shortcutsTitle = NSTextField(labelWithString: "Keyboard Shortcuts")
        shortcutsTitle.font = NSFont.systemFont(ofSize: 16, weight: .bold)
        shortcutsTitle.frame = NSRect(x: leftMargin, y: yPos, width: 460, height: 25)
        contentView.addSubview(shortcutsTitle)
        yPos -= 40
        
        let layoutLabel = NSTextField(labelWithString: "Switch Layout:")
        layoutLabel.frame = NSRect(x: leftMargin, y: yPos, width: 120, height: 20)
        contentView.addSubview(layoutLabel)
        layoutSwitchButton = NSButton(frame: NSRect(x: controlX, y: yPos - 5, width: 280, height: 30))
        layoutSwitchButton.title = TeximoSettings.shared.layoutSwitchHotkey.displayString
        layoutSwitchButton.bezelStyle = .rounded
        layoutSwitchButton.target = self
        layoutSwitchButton.action = #selector(recordLayoutSwitch)
        contentView.addSubview(layoutSwitchButton)
        layoutSwitchWarning = NSTextField(labelWithString: "")
        layoutSwitchWarning.frame = NSRect(x: controlX + 290, y: yPos, width: 30, height: 20)
        layoutSwitchWarning.textColor = .systemRed
        layoutSwitchWarning.font = NSFont.systemFont(ofSize: 16)
        contentView.addSubview(layoutSwitchWarning)
        yPos -= 40
        
        let translitLabel = NSTextField(labelWithString: "Transliterate Text:")
        translitLabel.frame = NSRect(x: leftMargin, y: yPos, width: 120, height: 20)
        contentView.addSubview(translitLabel)
        transliterationButton = NSButton(frame: NSRect(x: controlX, y: yPos - 5, width: 280, height: 30))
        transliterationButton.title = TeximoSettings.shared.transliterationHotkey.displayString
        transliterationButton.bezelStyle = .rounded
        transliterationButton.target = self
        transliterationButton.action = #selector(recordTransliteration)
        contentView.addSubview(transliterationButton)
        transliterationWarning = NSTextField(labelWithString: "")
        transliterationWarning.frame = NSRect(x: controlX + 290, y: yPos, width: 30, height: 20)
        transliterationWarning.textColor = .systemRed
        transliterationWarning.font = NSFont.systemFont(ofSize: 16)
        contentView.addSubview(transliterationWarning)
        yPos -= 40
        
        let caseLabel = NSTextField(labelWithString: "Toggle Case:")
        caseLabel.frame = NSRect(x: leftMargin, y: yPos, width: 120, height: 20)
        contentView.addSubview(caseLabel)
        caseToggleButton = NSButton(frame: NSRect(x: controlX, y: yPos - 5, width: 280, height: 30))
        caseToggleButton.title = TeximoSettings.shared.caseToggleHotkey.displayString
        caseToggleButton.bezelStyle = .rounded
        caseToggleButton.target = self
        caseToggleButton.action = #selector(recordCaseToggle)
        contentView.addSubview(caseToggleButton)
        caseToggleWarning = NSTextField(labelWithString: "")
        caseToggleWarning.frame = NSRect(x: controlX + 290, y: yPos, width: 30, height: 20)
        caseToggleWarning.textColor = .systemRed
        caseToggleWarning.font = NSFont.systemFont(ofSize: 16)
        contentView.addSubview(caseToggleWarning)
        yPos -= 35
        
        let infoLabel = NSTextField(labelWithString: "Press any key (Esc to cancel)")
        infoLabel.frame = NSRect(x: controlX, y: yPos, width: 300, height: 20)
        infoLabel.font = NSFont.systemFont(ofSize: 11)
        infoLabel.textColor = .secondaryLabelColor
        contentView.addSubview(infoLabel)
        
        let resetButton = NSButton(frame: NSRect(x: 20, y: 15, width: 140, height: 28))
        resetButton.title = "Reset to Defaults"
        resetButton.bezelStyle = .rounded
        resetButton.target = self
        resetButton.action = #selector(resetToDefaults)
        contentView.addSubview(resetButton)
        
        let closeButton = NSButton(frame: NSRect(x: 400, y: 15, width: 80, height: 28))
        closeButton.title = "Close"
        closeButton.bezelStyle = .rounded
        closeButton.target = self
        closeButton.action = #selector(closeWindow)
        closeButton.keyEquivalent = "\r"
        contentView.addSubview(closeButton)
    }
    
    // MARK: - Layout Selection
    
    private func populateLayoutPopup(_ popup: NSPopUpButton, language: String) {
        popup.removeAllItems()
        let layouts = language == "English" ? LayoutEnumerator.getEnglishLayouts() : LayoutEnumerator.getRussianLayouts()
        for layout in layouts {
            popup.addItem(withTitle: layout.displayName)
            popup.lastItem?.representedObject = layout
        }
        let currentLayout = language == "English" ? TeximoSettings.shared.selectedLayout1 : TeximoSettings.shared.selectedLayout2
        if let current = currentLayout, let index = layouts.firstIndex(where: { $0.sourceID == current.sourceID }) {
            popup.selectItem(at: index)
        } else if !layouts.isEmpty {
            popup.selectItem(at: 0)
            let firstLayout = layouts[0]
            if language == "English" {
                TeximoSettings.shared.selectedLayout1 = firstLayout
            } else {
                TeximoSettings.shared.selectedLayout2 = firstLayout
            }
        }
    }
    
    @objc private func layoutSelected(_ sender: NSPopUpButton) {
        let layout = sender.selectedItem?.representedObject as? KeyboardLayout
        if sender == englishLayoutPopup {
            TeximoSettings.shared.selectedLayout1 = layout
        } else if sender == russianLayoutPopup {
            TeximoSettings.shared.selectedLayout2 = layout
        }
    }
    
    // MARK: - Shortcut Recording
    
    @objc private func recordLayoutSwitch() {
        startRecording(for: "layout", button: layoutSwitchButton, previousValue: TeximoSettings.shared.layoutSwitchHotkey)
    }
    
    @objc private func recordTransliteration() {
        startRecording(for: "transliteration", button: transliterationButton, previousValue: TeximoSettings.shared.transliterationHotkey)
    }
    
    @objc private func recordCaseToggle() {
        startRecording(for: "caseToggle", button: caseToggleButton, previousValue: TeximoSettings.shared.caseToggleHotkey)
    }
    
    private func startRecording(for type: String, button: NSButton, previousValue: HotkeyConfig) {
        if let activeType = recordingFor {
            getButton(for: activeType)?.title = getPreviousConfig(for: activeType).displayString
        }
        stopRecording()
        recordingFor = type
        previousHotkey = previousValue
        lastModifiers = []
        button.title = "Press keys... (Esc to cancel)"
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyPress(event, for: type, button: button)
            return nil
        }
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event, for: type, button: button)
            return nil
        }
    }
    
    private func handleKeyPress(_ event: NSEvent, for type: String, button: NSButton) {
        guard recordingFor == type else { return }
        if event.keyCode == 53 {
            cancelRecording(for: type, button: button)
            return
        }
        let flags = event.modifierFlags
        var modifiers = Set<ModifierKey>()
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }
        saveHotkey(HotkeyConfig(modifiers: modifiers, keyCode: event.keyCode), for: type, button: button)
    }
    
    private func handleFlagsChanged(_ event: NSEvent, for type: String, button: NSButton) {
        guard recordingFor == type else { return }
        let flags = event.modifierFlags
        var modifiers = Set<ModifierKey>()
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.capsLock) && lastModifiers.isEmpty {
            saveHotkey(HotkeyConfig(modifiers: [], keyCode: 57), for: type, button: button)
            return
        }
        if lastModifiers.count >= 2 && modifiers.count < lastModifiers.count {
            saveHotkey(HotkeyConfig(modifiers: lastModifiers, keyCode: nil), for: type, button: button)
            return
        }
        lastModifiers = modifiers
    }
    
    private func saveHotkey(_ hotkey: HotkeyConfig, for type: String, button: NSButton) {
        switch type {
        case "layout":
            TeximoSettings.shared.layoutSwitchHotkey = hotkey
        case "transliteration":
            TeximoSettings.shared.transliterationHotkey = hotkey
        case "caseToggle":
            TeximoSettings.shared.caseToggleHotkey = hotkey
        default:
            break
        }
        button.title = hotkey.displayString
        stopRecording()
        checkConflicts()
    }
    
    private func cancelRecording(for type: String, button: NSButton) {
        if let previous = previousHotkey {
            button.title = previous.displayString
        }
        stopRecording()
    }
    
    private func stopRecording() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        if let monitor = flagsMonitor {
            NSEvent.removeMonitor(monitor)
            flagsMonitor = nil
        }
        recordingFor = nil
        previousHotkey = nil
        lastModifiers = []
    }
    
    private func getButton(for type: String) -> NSButton? {
        switch type {
        case "layout": return layoutSwitchButton
        case "transliteration": return transliterationButton
        case "caseToggle": return caseToggleButton
        default: return nil
        }
    }
    
    private func getPreviousConfig(for type: String) -> HotkeyConfig {
        switch type {
        case "layout": return TeximoSettings.shared.layoutSwitchHotkey
        case "transliteration": return TeximoSettings.shared.transliterationHotkey
        case "caseToggle": return TeximoSettings.shared.caseToggleHotkey
        default: return HotkeyConfig(modifiers: [])
        }
    }
    
    private func checkConflicts() {
        let layout = TeximoSettings.shared.layoutSwitchHotkey
        let translit = TeximoSettings.shared.transliterationHotkey
        let caseToggle = TeximoSettings.shared.caseToggleHotkey
        layoutSwitchWarning.stringValue = ""
        transliterationWarning.stringValue = ""
        caseToggleWarning.stringValue = ""
        if layout == translit {
            layoutSwitchWarning.stringValue = "⚠"
            transliterationWarning.stringValue = "⚠"
        }
        if layout == caseToggle {
            layoutSwitchWarning.stringValue = "⚠"
            caseToggleWarning.stringValue = "⚠"
        }
        if translit == caseToggle {
            transliterationWarning.stringValue = "⚠"
            caseToggleWarning.stringValue = "⚠"
        }
    }
    
    // MARK: - Startup
    
    private func isStartupEnabled() -> Bool {
        let script = """
        tell application "System Events"
            get the name of every login item
        end tell
        """
        var error: NSDictionary?
        if let applescript = NSAppleScript(source: script), let result = applescript.executeAndReturnError(&error).stringValue {
            return result.contains("Teximo")
        }
        return false
    }
    
    @objc private func toggleStartup(_ sender: NSButton) {
        let appPath = Bundle.main.bundlePath
        let appName = "Teximo"
        if sender.state == .on {
            let script = """
            tell application "System Events"
                make login item at end with properties {path:"\(appPath)", hidden:false, name:"\(appName)"}
            end tell
            """
            NSAppleScript(source: script)?.executeAndReturnError(nil)
        } else {
            let script = """
            tell application "System Events"
                delete login item "\(appName)"
            end tell
            """
            NSAppleScript(source: script)?.executeAndReturnError(nil)
        }
    }
    
    @objc private func resetToDefaults() {
        stopRecording()
        TeximoSettings.shared.resetToDefaults()
        layoutSwitchButton.title = TeximoSettings.shared.layoutSwitchHotkey.displayString
        transliterationButton.title = TeximoSettings.shared.transliterationHotkey.displayString
        caseToggleButton.title = TeximoSettings.shared.caseToggleHotkey.displayString
        checkConflicts()
        populateLayoutPopup(englishLayoutPopup, language: "English")
        populateLayoutPopup(russianLayoutPopup, language: "Russian")
    }
    
    @objc private func closeWindow() {
        stopRecording()
        self.close()
    }
}
