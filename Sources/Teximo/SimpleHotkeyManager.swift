import Cocoa

	final class SimpleHotkeyManager {
		struct Callbacks {
			var onCmdShift: (() -> Void)?
			var onOptionShift: (() -> Void)?
			var onControlShift: (() -> Void)?
		}

		private var callbacks = Callbacks()
		private var eventMonitor: Any?

		func start(callbacks: Callbacks) {
			print("[Teximo] SimpleHotkeyManager.start() called")
			let logPath = "/tmp/teximo_debug.log"
			let logMessage = "[Teximo] SimpleHotkeyManager.start() called\n"
			try? logMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
			
			self.callbacks = callbacks
			
			// Remove existing monitor if any
			stop()
			
			// Check if we have accessibility permissions
			let hasAccessibility = AccessibilityHelper.ensurePermission(promptIfNeeded: false)
			print("[Teximo] SimpleHotkeyManager: Accessibility permission: \(hasAccessibility)")
			let logMessage3 = "[Teximo] SimpleHotkeyManager: Accessibility permission: \(hasAccessibility)\n"
			try? logMessage3.write(toFile: logPath, atomically: true, encoding: .utf8)

			// Use NSEvent monitors for global hotkey detection
			eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
				print("[Teximo] SimpleHotkeyManager: Global event detected")
				let logMessage = "[Teximo] SimpleHotkeyManager: Global event detected\n"
				try? logMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
				self?.handleFlagsChanged(event)
			}
			
			if eventMonitor != nil {
				print("[Teximo] SimpleHotkeyManager: Global event monitor created")
				let logMessage = "[Teximo] SimpleHotkeyManager: Global event monitor created\n"
				try? logMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
			} else {
				print("[Teximo] SimpleHotkeyManager: Failed to create global event monitor")
				let logMessage = "[Teximo] SimpleHotkeyManager: Failed to create global event monitor\n"
				try? logMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
			}
			
			print("[Teximo] SimpleHotkeyManager: NSEvent-based hotkey detection started")
			let logMessage2 = "[Teximo] SimpleHotkeyManager: NSEvent-based hotkey detection started\n"
			try? logMessage2.write(toFile: logPath, atomically: true, encoding: .utf8)
		}

		func stop() {
			if let monitor = eventMonitor {
				NSEvent.removeMonitor(monitor)
				eventMonitor = nil
			}
		}

	private var lastFlags: NSEvent.ModifierFlags = []
	private var lastInvocationDate: Date = .distantPast
	private let debounceInterval: TimeInterval = 0.25

	private func handleFlagsChanged(_ event: NSEvent) {
		let currentFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
		let hasShift = currentFlags.contains(.shift)
		let hasCmd = currentFlags.contains(.command)
		let hasOpt = currentFlags.contains(.option)
		let hasCtrl = currentFlags.contains(.control)

		print("[Teximo] SimpleHotkeyManager: handleFlagsChanged - Shift: \(hasShift), Cmd: \(hasCmd), Opt: \(hasOpt), Ctrl: \(hasCtrl)")
		let logPath = "/tmp/teximo_debug.log"
		let logMessage = "[Teximo] SimpleHotkeyManager: handleFlagsChanged - Shift: \(hasShift), Cmd: \(hasCmd), Opt: \(hasOpt), Ctrl: \(hasCtrl)\n"
		try? logMessage.write(toFile: logPath, atomically: true, encoding: .utf8)

		// Only process when keys are pressed (not released)
		guard currentFlags != lastFlags else { 
			print("[Teximo] SimpleHotkeyManager: Flags unchanged, skipping")
			let logMessage2 = "[Teximo] SimpleHotkeyManager: Flags unchanged, skipping\n"
			try? logMessage2.write(toFile: logPath, atomically: true, encoding: .utf8)
			return 
		}
		
		lastFlags = currentFlags

		// Check if this is a key press (keys were added)
		let isKeyPress = (hasShift || hasCmd || hasOpt || hasCtrl)
		print("[Teximo] SimpleHotkeyManager: isKeyPress: \(isKeyPress)")
		let logMessage3 = "[Teximo] SimpleHotkeyManager: isKeyPress: \(isKeyPress)\n"
		try? logMessage3.write(toFile: logPath, atomically: true, encoding: .utf8)
		
		if isKeyPress {
			// Check for shortcuts immediately
			print("[Teximo] SimpleHotkeyManager: Calling checkForShortcuts")
			let logMessage4 = "[Teximo] SimpleHotkeyManager: Calling checkForShortcuts\n"
			try? logMessage4.write(toFile: logPath, atomically: true, encoding: .utf8)
			checkForShortcuts()
		}
	}
	
	private func checkForShortcuts() {
		let currentFlags = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
		let hasShift = currentFlags.contains(.shift)
		let hasCmd = currentFlags.contains(.command)
		let hasOpt = currentFlags.contains(.option)
		let hasCtrl = currentFlags.contains(.control)
		
		let now = Date()
		guard now.timeIntervalSince(lastInvocationDate) > debounceInterval else { return }
		
		let logPath = "/tmp/teximo_debug.log"
		
		if hasShift && hasCmd && !hasOpt && !hasCtrl {
			lastInvocationDate = now
			print("[Teximo] SimpleHotkeyManager: Triggering Cmd+Shift callback")
			let logMessage = "[Teximo] SimpleHotkeyManager: Triggering Cmd+Shift callback\n"
			try? logMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
			callbacks.onCmdShift?()
		} else if hasShift && hasOpt && !hasCmd && !hasCtrl {
			lastInvocationDate = now
			print("[Teximo] SimpleHotkeyManager: Triggering Option+Shift callback")
			let logMessage = "[Teximo] SimpleHotkeyManager: Triggering Option+Shift callback\n"
			try? logMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
			callbacks.onOptionShift?()
		} else if hasShift && hasCtrl && !hasCmd && !hasOpt {
			lastInvocationDate = now
			print("[Teximo] SimpleHotkeyManager: Triggering Control+Shift callback")
			let logMessage = "[Teximo] SimpleHotkeyManager: Triggering Control+Shift callback\n"
			try? logMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
			callbacks.onControlShift?()
		}
	}
}
