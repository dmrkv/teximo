import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
	private var statusItem: NSStatusItem!
	private let statusMenu = NSMenu()
	private let hotkeyDetector = TimerBasedHotkeyDetector()
	private var debugWindow: NSWindow?

	override init() {
		super.init()
		print("[Teximo] AppDelegate init called")
		// Write to file immediately
		let logPath = "/tmp/teximo_debug.log"
		let logMessage = "[Teximo] AppDelegate init called\n"
		try? logMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
		
		// Force immediate UI creation
		DispatchQueue.main.async { [weak self] in
			guard let self else { return }
			self.setupStatusItem()
			self.showDebugWindow()
		}
	}

	func applicationDidFinishLaunching(_ notification: Notification) {
		// Write to file for debugging
		let logPath = "/tmp/teximo_debug.log"
		let logMessage = "[Teximo] applicationDidFinishLaunching - START\n"
		try? logMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
		
		print("[Teximo] applicationDidFinishLaunching - START")
		NSApp.setActivationPolicy(.accessory)
		print("[Teximo] Set activation policy to accessory")
		
		// Force immediate UI creation without async
		print("[Teximo] Creating UI immediately...")
		setupStatusItem()
		print("[Teximo] UI created, checking accessibility...")
		_ = AccessibilityHelper.ensurePermission(promptIfNeeded: false)
		print("[Teximo] Starting hotkeys...")
		let hotkeysLogMessage = "[Teximo] Starting hotkeys...\n"
		try? hotkeysLogMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
		
		hotkeyDetector.start { [weak self] in
			self?.handleCmdShift()
		}
		
		print("[Teximo] Hotkeys started")
		let hotkeysStartedMessage = "[Teximo] Hotkeys started\n"
		try? hotkeysStartedMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
		print("[Teximo] applicationDidFinishLaunching - END")
		
		// Write completion to file
		let endMessage = "[Teximo] applicationDidFinishLaunching - END\n"
		if let fileHandle = FileHandle(forWritingAtPath: logPath) {
			fileHandle.seekToEndOfFile()
			fileHandle.write(endMessage.data(using: .utf8)!)
			fileHandle.closeFile()
		}
	}

	private func showDebugWindow() {
		print("[Teximo] showDebugWindow - START")
		let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 120),
							styleMask: [.titled, .closable],
							backing: .buffered,
							defer: false)
		window.title = "Teximo Debug"
		let label = NSTextField(labelWithString: "Teximo is running. Menu bar should show ⌨︎.")
		label.frame = NSRect(x: 20, y: 50, width: 280, height: 20)
		window.contentView?.addSubview(label)
		window.center()
		print("[Teximo] About to show window...")
		window.makeKeyAndOrderFront(nil)
		NSApp.activate(ignoringOtherApps: true)
		print("[Teximo] Window should be visible now")
		self.debugWindow = window
		print("[Teximo] showDebugWindow - END")
	}

	private func setupStatusItem() {
		guard statusItem == nil else {
			print("[Teximo] Status item already exists, skipping setup")
			return
		}
		print("[Teximo] Creating status item…")
		statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
		print("[Teximo] Status item created: \(statusItem != nil)")
		if let button = statusItem.button {
			print("[Teximo] Status button created")
			button.title = "⌨︎"
			print("[Teximo] Button title set to: \(button.title ?? "nil")")
		} else {
			print("[Teximo] ERROR: Status button is nil!")
		}
		let testItem = NSMenuItem(title: "Test Action", action: #selector(testAction), keyEquivalent: "t")
		testItem.target = self
		statusMenu.addItem(testItem)
		statusMenu.addItem(NSMenuItem.separator())
		let showItem = NSMenuItem(title: "Show Test Window", action: #selector(showWindowAction), keyEquivalent: "w")
		showItem.target = self
		statusMenu.addItem(showItem)
		statusMenu.addItem(NSMenuItem.separator())

		let aboutItem = NSMenuItem(title: "Teximo", action: nil, keyEquivalent: "")
		aboutItem.isEnabled = false
		statusMenu.addItem(aboutItem)
		statusMenu.addItem(NSMenuItem.separator())
		statusMenu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

		statusItem.menu = statusMenu
		print("[Teximo] Status item set up - menu items: \(statusMenu.items.count)")
	}

	@objc private func testAction() {
		let alert = NSAlert()
		alert.messageText = "Test action fired"
		alert.runModal()
	}

    @objc private func showWindowAction() {
        if debugWindow == nil {
            showDebugWindow()
        } else {
            debugWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

	@objc private func quit() {
		hotkeyDetector.stop()
		NSApp.terminate(nil)
	}

	private func handleCmdShift() {
		print("[Teximo] Cmd+Shift detected - switching layout")
		SimpleLayoutSwitcher.switchLayout()
	}

	private func handleOptionShift() {
		print("[Teximo] Option+Shift detected")
		do {
			guard let text = TextActions.getSelectionStringViaClipboard(), !text.isEmpty else { 
				print("[Teximo] No selection to transliterate"); 
				return 
			}
			let converted = Transliterator.transliterate(text)
			TextActions.replaceSelection(with: converted)
		} catch {
			print("[Teximo] Error in handleOptionShift: \(error)")
		}
	}

	private func handleControlShift() {
		print("[Teximo] Control+Shift detected")
		do {
			guard let text = TextActions.getSelectionStringViaClipboard(), !text.isEmpty else { 
				print("[Teximo] No selection to case-toggle"); 
				return 
			}
			let converted = CaseToggle.transform(text)
			TextActions.replaceSelection(with: converted)
		} catch {
			print("[Teximo] Error in handleControlShift: \(error)")
		}
	}
}
