import Cocoa
import ServiceManagement

@MainActor
class SimpleAppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let statusMenu = NSMenu()
    private let shortcuts = GlobalShortcutMonitor()
    private let translation = SelectionTranslationController()
    private var permissionWindow: AccessibilityPermissionWindow?
    private var textInteractionRevision = 0
    private var isPerformingTextAction = false

    // Settings window
    private var settingsWindow: SettingsWindow?
    
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
            
            // If menu bar icon is hidden, show Settings window (only after permissions granted)
            if !TeximoSettings.shared.showMenuBarIcon {
                showSettingsWindow()
            }
        }
        
        // Show notch warning if needed (on first launch on notched Macs)
        if NotchDetector.shouldShowNotchWarning() {
            // Delay to ensure app is fully launched
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                NotchDetector.showNotchWarning()
                NotchDetector.markWarningShown()
            }
        }
        
        migrateLaunchAtLoginIfNeeded()
        
        print("[Teximo] SimpleAppDelegate applicationDidFinishLaunching - END")
    }
    
    // Handle app reopen (when user clicks app icon or runs 'open' while already running)
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        print("[Teximo] App reopened, hasVisibleWindows: \(flag)")
        
        // Always show Settings window when app is re-launched
        showSettingsWindow()
        
        return true
    }
    
    private func setupStatusItem() {
        print("[Teximo] Creating status item…")
        
        // Clear existing menu to prevent duplicates
        statusMenu.removeAllItems()
        
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        }
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
        
        // Set visibility based on settings
        statusItem.isVisible = TeximoSettings.shared.showMenuBarIcon
        print("[Teximo] Status item set up, visible: \(statusItem.isVisible)")

        // Show current shortcuts (non-clickable info items)
        let layoutShortcut = TeximoSettings.shared.layoutSwitchHotkey?.displayString ?? "Disabled"
        let layoutItem = NSMenuItem(title: "Switch Layout: \(layoutShortcut)", action: nil, keyEquivalent: "")
        layoutItem.isEnabled = false
        statusMenu.addItem(layoutItem)
        
        let translitShortcut = TeximoSettings.shared.transliterationHotkey?.displayString ?? "Disabled"
        let translitItem = NSMenuItem(title: "Transliterate Text: \(translitShortcut)", action: nil, keyEquivalent: "")
        translitItem.isEnabled = false
        statusMenu.addItem(translitItem)
        
        let caseShortcut = TeximoSettings.shared.caseToggleHotkey?.displayString ?? "Disabled"
        let caseItem = NSMenuItem(title: "Toggle Case: \(caseShortcut)", action: nil, keyEquivalent: "")
        caseItem.isEnabled = false
        statusMenu.addItem(caseItem)
        
        let translationShortcut = TeximoSettings.shared.translationHotkey?.displayString ?? "Disabled"
        let translationItem = NSMenuItem(title: "Translate Selection: \(translationShortcut)", action: nil, keyEquivalent: "")
        translationItem.isEnabled = false
        statusMenu.addItem(translationItem)

        statusMenu.addItem(NSMenuItem.separator())

        // Get app version
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let versionItem = NSMenuItem(title: "Teximo v\(version).\(buildNumber)", action: nil, keyEquivalent: "")
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
        translation.onOpenSettings = { [weak self] in self?.showSettingsWindow() }
        shortcuts.onUserInteraction = { [weak self] in
            self?.textInteractionRevision += 1
            self?.translation.selectionMayHaveChanged()
        }
        shortcuts.onAction = { [weak self] action in
            guard let self else { return }
            switch action {
            case .layout: self.switchLayout()
            case .transliteration: self.transformSelectedText(Transliterator.transliterate)
            case .caseToggle: self.transformSelectedText(CaseToggle.transform)
            case .translation:
                guard !self.isPerformingTextAction else { return }
                self.translation.translateSelection()
            }
        }
        shortcuts.start()
        if !shortcuts.canHandleKeyShortcuts {
            showSettingsWindow()
            settingsWindow?.showShortcutPermissionError()
        }
    }

    private func transformSelectedText(_ transform: @escaping (String) -> String) {
        guard !isPerformingTextAction,
              AccessibilityHelper.ensurePermission(promptIfNeeded: false) else { return }
        isPerformingTextAction = true
        translation.selectionMayHaveChanged()
        let revision = textInteractionRevision
        let environment = TextActions.Environment.live { [weak self] in
            self?.textInteractionRevision == revision
        }
        Task { [weak self] in
            defer { self?.isPerformingTextAction = false }
            let outcome = await TextActions.transformSelection(transform, environment: environment)
            if outcome == .noSelection { NSLog("[Teximo] No selected text available for text action.") }
        }
    }

    private func switchLayout() {
        SimpleLayoutSwitcher.switchLayout()
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
        showSettingsWindow()
    }
    
    private func showSettingsWindow() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow()
            settingsWindow?.onSettingsChanged = { [weak self] in
                guard let self else { return }
                self.setupStatusItem()
            }
            settingsWindow?.onMenuBarVisibilityChanged = { [weak self] in
                self?.updateMenuBarVisibility()
            }
        }
        
        // If menu bar icon is hidden, need to change activation policy to show window
        if !TeximoSettings.shared.showMenuBarIcon {
            NSApp.setActivationPolicy(.regular)
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Restore accessory policy after showing window
        if !TeximoSettings.shared.showMenuBarIcon {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
    
    private func updateMenuBarVisibility() {
        statusItem.isVisible = TeximoSettings.shared.showMenuBarIcon
        print("[Teximo] Menu bar icon visibility updated: \(statusItem.isVisible)")
    }
    
    @objc private func quit() {
        NSApp.terminate(nil)
    }
    
    @objc private func toggleStartup() {
        let isEnabled = isStartupEnabled()
        setStartupEnabled(!isEnabled)
        
        if let startupItem = statusMenu.items.first(where: { $0.title.contains("Start Teximo when macOS starts") }) {
            startupItem.state = isStartupEnabled() ? .on : .off
        }
    }
    
    private func isStartupEnabled() -> Bool {
        SMAppService.mainApp.status == .enabled
    }
    
    private func setStartupEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                removeLegacyLoginItemIfNeeded()
                print("[Teximo] Successfully registered launch at login")
            } else {
                try SMAppService.mainApp.unregister()
                removeLegacyLoginItemIfNeeded()
                print("[Teximo] Successfully unregistered launch at login")
            }
            UserDefaults.standard.set(enabled, forKey: "TeximoStartupEnabled")
        } catch {
            print("[Teximo] Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
        }
    }
    
    /// Migrates users who enabled startup via the legacy AppleScript login-item API.
    private func migrateLaunchAtLoginIfNeeded() {
        let preferred = UserDefaults.standard.bool(forKey: "TeximoStartupEnabled")
        guard preferred, SMAppService.mainApp.status != .enabled else { return }
        setStartupEnabled(true)
    }
    
    /// Removes duplicate launch entries created by the pre-1.x AppleScript approach.
    private func removeLegacyLoginItemIfNeeded() {
        let script = """
        tell application "System Events"
            if exists login item "Teximo" then
                delete login item "Teximo"
            end if
        end tell
        """
        NSAppleScript(source: script)?.executeAndReturnError(nil)
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
