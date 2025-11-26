import Cocoa

class SettingsWindow: NSWindow {
    private var layoutSwitchButton: NSButton!
    private var transliterationButton: NSButton!
    private var caseToggleButton: NSButton!
    private var layoutSwitchClearButton: NSButton!
    private var transliterationClearButton: NSButton!
    private var caseToggleClearButton: NSButton!
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
        self.title = "Teximo Settings"
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
        yPos -= 30
        
        let menuBarIconCheckbox = NSButton(checkboxWithTitle: "Show icon in menu bar", target: self, action: #selector(toggleMenuBarIcon))
        menuBarIconCheckbox.frame = NSRect(x: leftMargin, y: yPos, width: 300, height: 20)
        menuBarIconCheckbox.state = TeximoSettings.shared.showMenuBarIcon ? .on : .off
        contentView.addSubview(menuBarIconCheckbox)
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
        layoutSwitchButton = NSButton(frame: NSRect(x: controlX, y: yPos - 5, width: 250, height: 30))
        layoutSwitchButton.title = TeximoSettings.shared.layoutSwitchHotkey?.displayString ?? "Record Shortcut"
        layoutSwitchButton.bezelStyle = .rounded
        layoutSwitchButton.target = self
        layoutSwitchButton.action = #selector(recordLayoutSwitch)
        contentView.addSubview(layoutSwitchButton)
        layoutSwitchClearButton = NSButton(frame: NSRect(x: controlX + 255, y: yPos - 5, width: 25, height: 30))
        layoutSwitchClearButton.title = "×"
        layoutSwitchClearButton.bezelStyle = .rounded
        layoutSwitchClearButton.target = self
        layoutSwitchClearButton.action = #selector(clearLayoutSwitch)
        layoutSwitchClearButton.isHidden = TeximoSettings.shared.layoutSwitchHotkey == nil
        contentView.addSubview(layoutSwitchClearButton)
        layoutSwitchWarning = NSTextField(labelWithString: "")
        layoutSwitchWarning.frame = NSRect(x: controlX + 290, y: yPos, width: 30, height: 20)
        layoutSwitchWarning.textColor = .systemRed
        layoutSwitchWarning.font = NSFont.systemFont(ofSize: 16)
        contentView.addSubview(layoutSwitchWarning)
        yPos -= 40
        
        let translitLabel = NSTextField(labelWithString: "Transliterate Text:")
        translitLabel.frame = NSRect(x: leftMargin, y: yPos, width: 120, height: 20)
        contentView.addSubview(translitLabel)
        transliterationButton = NSButton(frame: NSRect(x: controlX, y: yPos - 5, width: 250, height: 30))
        transliterationButton.title = TeximoSettings.shared.transliterationHotkey?.displayString ?? "Record Shortcut"
        transliterationButton.bezelStyle = .rounded
        transliterationButton.target = self
        transliterationButton.action = #selector(recordTransliteration)
        contentView.addSubview(transliterationButton)
        transliterationClearButton = NSButton(frame: NSRect(x: controlX + 255, y: yPos - 5, width: 25, height: 30))
        transliterationClearButton.title = "×"
        transliterationClearButton.bezelStyle = .rounded
        transliterationClearButton.target = self
        transliterationClearButton.action = #selector(clearTransliteration)
        transliterationClearButton.isHidden = TeximoSettings.shared.transliterationHotkey == nil
        contentView.addSubview(transliterationClearButton)
        transliterationWarning = NSTextField(labelWithString: "")
        transliterationWarning.frame = NSRect(x: controlX + 290, y: yPos, width: 30, height: 20)
        transliterationWarning.textColor = .systemRed
        transliterationWarning.font = NSFont.systemFont(ofSize: 16)
        contentView.addSubview(transliterationWarning)
        yPos -= 40
        
        let caseLabel = NSTextField(labelWithString: "Toggle Case:")
        caseLabel.frame = NSRect(x: leftMargin, y: yPos, width: 120, height: 20)
        contentView.addSubview(caseLabel)
        caseToggleButton = NSButton(frame: NSRect(x: controlX, y: yPos - 5, width: 250, height: 30))
        caseToggleButton.title = TeximoSettings.shared.caseToggleHotkey?.displayString ?? "Record Shortcut"
        caseToggleButton.bezelStyle = .rounded
        caseToggleButton.target = self
        caseToggleButton.action = #selector(recordCaseToggle)
        contentView.addSubview(caseToggleButton)
        caseToggleClearButton = NSButton(frame: NSRect(x: controlX + 255, y: yPos - 5, width: 25, height: 30))
        caseToggleClearButton.title = "×"
        caseToggleClearButton.bezelStyle = .rounded
        caseToggleClearButton.target = self
        caseToggleClearButton.action = #selector(clearCaseToggle)
        caseToggleClearButton.isHidden = TeximoSettings.shared.caseToggleHotkey == nil
        contentView.addSubview(caseToggleClearButton)
        caseToggleWarning = NSTextField(labelWithString: "")
        caseToggleWarning.frame = NSRect(x: controlX + 290, y: yPos, width: 30, height: 20)
        caseToggleWarning.textColor = .systemRed
        caseToggleWarning.font = NSFont.systemFont(ofSize: 16)
        contentView.addSubview(caseToggleWarning)
        yPos -= 50
        
        // RESET AND CLOSE BUTTONS
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
    
    private func startRecording(for type: String, button: NSButton, previousValue: HotkeyConfig?) {
        if let activeType = recordingFor {
            getButton(for: activeType)?.title = getPreviousConfig(for: activeType)?.displayString ?? "Record Shortcut"
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
        // Update button text
        if let button = getButton(for: recordingFor!) {
            button.title = hotkey.displayString
        }
        
        // Update clear button visibility
        updateClearButtonVisibility()
        
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
    
    private func getPreviousConfig(for type: String) -> HotkeyConfig? {
        switch type {
        case "layout": return TeximoSettings.shared.layoutSwitchHotkey
        case "transliteration": return TeximoSettings.shared.transliterationHotkey
        case "caseToggle": return TeximoSettings.shared.caseToggleHotkey
        default: return nil
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
        layoutSwitchButton.title = TeximoSettings.shared.layoutSwitchHotkey?.displayString ?? "Record Shortcut"
        transliterationButton.title = TeximoSettings.shared.transliterationHotkey?.displayString ?? "Record Shortcut"
        caseToggleButton.title = TeximoSettings.shared.caseToggleHotkey?.displayString ?? "Record Shortcut"
        checkConflicts()
        populateLayoutPopup(englishLayoutPopup, language: "English")
        populateLayoutPopup(russianLayoutPopup, language: "Russian")
    }
    
    // MARK: - Clear Shortcuts
    
    @objc private func clearLayoutSwitch() {
        TeximoSettings.shared.layoutSwitchHotkey = nil
        layoutSwitchButton.title = "Record Shortcut"
        layoutSwitchClearButton.isHidden = true
        checkConflicts()
    }
    
    @objc private func clearTransliteration() {
        TeximoSettings.shared.transliterationHotkey = nil
        transliterationButton.title = "Record Shortcut"
        transliterationClearButton.isHidden = true
        checkConflicts()
    }
    
    @objc private func clearCaseToggle() {
        TeximoSettings.shared.caseToggleHotkey = nil
        caseToggleButton.title = "Record Shortcut"
        caseToggleClearButton.isHidden = true
        checkConflicts()
    }
    
    private func updateClearButtonVisibility() {
        layoutSwitchClearButton.isHidden = TeximoSettings.shared.layoutSwitchHotkey == nil
        transliterationClearButton.isHidden = TeximoSettings.shared.transliterationHotkey == nil
        caseToggleClearButton.isHidden = TeximoSettings.shared.caseToggleHotkey == nil
    }
    
    var onMenuBarVisibilityChanged: (() -> Void)?
    
    @objc private func toggleMenuBarIcon(_ sender: NSButton) {
        TeximoSettings.shared.showMenuBarIcon = (sender.state == .on)
        onMenuBarVisibilityChanged?()
    }
    
    @objc private func closeWindow() {
        stopRecording()
        self.close()
    }
}
