import Cocoa

final class WorkingHotkeyManager {
	struct Callbacks {
		var onCmdShift: (() -> Void)?
		var onOptionShift: (() -> Void)?
		var onControlShift: (() -> Void)?
	}

	private var callbacks = Callbacks()
	private var eventMonitor: Any?
	private var lastFlags: NSEvent.ModifierFlags = []
	private var lastInvocationDate: Date = .distantPast
	private let debounceInterval: TimeInterval = 0.25

	func start(callbacks: Callbacks) {
		print("[Teximo] WorkingHotkeyManager.start() called")
		let logPath = "/tmp/teximo_debug.log"
		let logMessage = "[Teximo] WorkingHotkeyManager.start() called\n"
		try? logMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
		
		self.callbacks = callbacks
		
		// Remove existing monitor if any
		stop()
		
		// Use NSEvent monitors for global hotkey detection
		eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
			print("[Teximo] WorkingHotkeyManager: Global event detected")
			let logMessage = "[Teximo] WorkingHotkeyManager: Global event detected\n"
			try? logMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
			self?.handleFlagsChanged(event)
		}
		
		if eventMonitor != nil {
			print("[Teximo] WorkingHotkeyManager: Global event monitor created")
			let logMessage = "[Teximo] WorkingHotkeyManager: Global event monitor created\n"
			try? logMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
		} else {
			print("[Teximo] WorkingHotkeyManager: Failed to create global event monitor")
			let logMessage = "[Teximo] WorkingHotkeyManager: Failed to create global event monitor\n"
			try? logMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
		}
		
		print("[Teximo] WorkingHotkeyManager: NSEvent-based hotkey detection started")
		let logMessage2 = "[Teximo] WorkingHotkeyManager: NSEvent-based hotkey detection started\n"
		try? logMessage2.write(toFile: logPath, atomically: true, encoding: .utf8)
	}

	func stop() {
		if let monitor = eventMonitor {
			NSEvent.removeMonitor(monitor)
			eventMonitor = nil
		}
	}

	private func handleFlagsChanged(_ event: NSEvent) {
		let currentFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
		let hasShift = currentFlags.contains(.shift)
		let hasCmd = currentFlags.contains(.command)
		let hasOpt = currentFlags.contains(.option)
		let hasCtrl = currentFlags.contains(.control)

		print("[Teximo] WorkingHotkeyManager: handleFlagsChanged - Shift: \(hasShift), Cmd: \(hasCmd), Opt: \(hasOpt), Ctrl: \(hasCtrl)")
		let logPath = "/tmp/teximo_debug.log"
		let logMessage = "[Teximo] WorkingHotkeyManager: handleFlagsChanged - Shift: \(hasShift), Cmd: \(hasCmd), Opt: \(hasOpt), Ctrl: \(hasCtrl)\n"
		try? logMessage.write(toFile: logPath, atomically: true, encoding: .utf8)

		// Only process when keys are pressed (not released)
		guard currentFlags != lastFlags else { 
			print("[Teximo] WorkingHotkeyManager: Flags unchanged, skipping")
			let logMessage2 = "[Teximo] WorkingHotkeyManager: Flags unchanged, skipping\n"
			try? logMessage2.write(toFile: logPath, atomically: true, encoding: .utf8)
			return 
		}
		
		lastFlags = currentFlags

		// Check if this is a key press (keys were added)
		let isKeyPress = (hasShift || hasCmd || hasOpt || hasCtrl)
		print("[Teximo] WorkingHotkeyManager: isKeyPress: \(isKeyPress)")
		let logMessage3 = "[Teximo] WorkingHotkeyManager: isKeyPress: \(isKeyPress)\n"
		try? logMessage3.write(toFile: logPath, atomically: true, encoding: .utf8)
		
		if isKeyPress {
			// Check for shortcuts immediately
			print("[Teximo] WorkingHotkeyManager: Calling checkForShortcuts")
			let logMessage4 = "[Teximo] WorkingHotkeyManager: Calling checkForShortcuts\n"
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
			print("[Teximo] WorkingHotkeyManager: Triggering Cmd+Shift callback")
			let logMessage = "[Teximo] WorkingHotkeyManager: Triggering Cmd+Shift callback\n"
			try? logMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
			callbacks.onCmdShift?()
		} else if hasShift && hasOpt && !hasCmd && !hasCtrl {
			lastInvocationDate = now
			print("[Teximo] WorkingHotkeyManager: Triggering Option+Shift callback")
			let logMessage = "[Teximo] WorkingHotkeyManager: Triggering Option+Shift callback\n"
			try? logMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
			callbacks.onOptionShift?()
		} else if hasShift && hasCtrl && !hasCmd && !hasOpt {
			lastInvocationDate = now
			print("[Teximo] WorkingHotkeyManager: Triggering Control+Shift callback")
			let logMessage = "[Teximo] WorkingHotkeyManager: Triggering Control+Shift callback\n"
			try? logMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
			callbacks.onControlShift?()
		}
	}
}

