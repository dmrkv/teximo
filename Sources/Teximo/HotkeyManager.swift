import Cocoa
import Carbon

final class HotkeyManager {
	struct Callbacks {
		var onCmdShift: (() -> Void)?
		var onOptionShift: (() -> Void)?
		var onControlShift: (() -> Void)?
	}

	private var eventTap: CFMachPort?
	private var runLoopSource: CFRunLoopSource?
	private var globalMonitor: Any?
	private var localMonitor: Any?
	private var callbacks = Callbacks()

	private var currentFlags: NSEvent.ModifierFlags = []
	private var lastInvocationDate: Date = .distantPast
	private let debounceInterval: TimeInterval = 0.25

	func start(callbacks: Callbacks) {
		print("[Teximo] HotkeyManager.start() called")
		// Write to file immediately
		let logPath = "/tmp/teximo_debug.log"
		let logMessage = "[Teximo] HotkeyManager.start() called\n"
		try? logMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
		self.callbacks = callbacks
		
		// Check if we have accessibility permissions first
		let hasAccessibility = AccessibilityHelper.ensurePermission(promptIfNeeded: false)
		print("[Teximo] HotkeyManager: Accessibility permission: \(hasAccessibility)")
		let logMessage3 = "[Teximo] HotkeyManager: Accessibility permission: \(hasAccessibility)\n"
		try? logMessage3.write(toFile: logPath, atomically: true, encoding: .utf8)
		
		guard hasAccessibility else {
			print("[Teximo] HotkeyManager: No accessibility permissions, using NSEvent monitors only")
			let logMessage2 = "[Teximo] HotkeyManager: No accessibility permissions, using NSEvent monitors only\n"
			try? logMessage2.write(toFile: logPath, atomically: true, encoding: .utf8)
			installNSEventMonitors()
			return
		}
		
		if eventTap == nil {
			let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
			print("[Teximo] HotkeyManager: Creating event tap with mask: \(mask)")
			let tap = CGEvent.tapCreate(
				tap: .cgSessionEventTap,
				place: .headInsertEventTap,
				options: .defaultTap,
				eventsOfInterest: mask,
				callback: { proxy, type, cgEvent, refcon in
					guard type == .flagsChanged else { return Unmanaged.passUnretained(cgEvent) }
					let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon!).takeUnretainedValue()
					manager.handleFlagsChanged(cgEvent: cgEvent)
					return Unmanaged.passUnretained(cgEvent)
				},
				userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
			)
			if let tap = tap {
				print("[Teximo] HotkeyManager: Event tap created successfully")
				// Write to file
				let logPath = "/tmp/teximo_debug.log"
				let logMessage = "[Teximo] HotkeyManager: Event tap created successfully\n"
				try? logMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
				self.eventTap = tap
				let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
				self.runLoopSource = source
				CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
				CGEvent.tapEnable(tap: tap, enable: true)
				print("[Teximo] Event tap installed")
				// Write to file
				let logMessage2 = "[Teximo] Event tap installed\n"
				try? logMessage2.write(toFile: logPath, atomically: true, encoding: .utf8)
			} else {
				print("[Teximo] Event tap not available; falling back to NSEvent monitors")
				// Write to file
				let logPath = "/tmp/teximo_debug.log"
				let logMessage = "[Teximo] Event tap not available; falling back to NSEvent monitors\n"
				try? logMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
				installNSEventMonitors()
			}
		}
	}

	func stop() {
		if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
		if let source = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
		runLoopSource = nil
		eventTap = nil
		if let gm = globalMonitor { NSEvent.removeMonitor(gm) }
		if let lm = localMonitor { NSEvent.removeMonitor(lm) }
		globalMonitor = nil
		localMonitor = nil
	}

	private func handleFlagsChanged(cgEvent: CGEvent) {
		let raw = UInt(cgEvent.flags.rawValue)
		let masked = raw & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue
		let flags = NSEvent.ModifierFlags(rawValue: masked)
		currentFlags = flags

		let hasShift = flags.contains(NSEvent.ModifierFlags.shift)
		let hasCmd = flags.contains(NSEvent.ModifierFlags.command)
		let hasOpt = flags.contains(NSEvent.ModifierFlags.option)
		let hasCtrl = flags.contains(NSEvent.ModifierFlags.control)

		let now = Date()
		guard now.timeIntervalSince(lastInvocationDate) > debounceInterval else { return }

		if hasShift && hasCmd && !hasOpt && !hasCtrl {
			lastInvocationDate = now
			print("[Teximo] HotkeyManager: Triggering Cmd+Shift callback")
			callbacks.onCmdShift?()
		} else if hasShift && hasOpt && !hasCmd && !hasCtrl {
			lastInvocationDate = now
			print("[Teximo] HotkeyManager: Triggering Option+Shift callback")
			callbacks.onOptionShift?()
		} else if hasShift && hasCtrl && !hasCmd && !hasOpt {
			lastInvocationDate = now
			print("[Teximo] HotkeyManager: Triggering Control+Shift callback")
			callbacks.onControlShift?()
		}
	}

	private func installNSEventMonitors() {
		print("[Teximo] HotkeyManager: Installing NSEvent monitors")
		globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
			print("[Teximo] HotkeyManager: Global monitor triggered")
			self?.handleFlagsChangedFromNSEvent(event: event)
		}
		localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
			print("[Teximo] HotkeyManager: Local monitor triggered")
			self?.handleFlagsChangedFromNSEvent(event: event)
			return event
		}
		print("[Teximo] HotkeyManager: NSEvent monitors installed")
	}

	private func handleFlagsChangedFromNSEvent(event: NSEvent) {
		let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
		currentFlags = flags
		let hasShift = flags.contains(.shift)
		let hasCmd = flags.contains(.command)
		let hasOpt = flags.contains(.option)
		let hasCtrl = flags.contains(.control)
		let now = Date()
		guard now.timeIntervalSince(lastInvocationDate) > debounceInterval else { return }
		if hasShift && hasCmd && !hasOpt && !hasCtrl {
			lastInvocationDate = now
			print("[Teximo] HotkeyManager: Triggering Cmd+Shift callback")
			callbacks.onCmdShift?()
		} else if hasShift && hasOpt && !hasCmd && !hasCtrl {
			lastInvocationDate = now
			print("[Teximo] HotkeyManager: Triggering Option+Shift callback")
			callbacks.onOptionShift?()
		} else if hasShift && hasCtrl && !hasCmd && !hasOpt {
			lastInvocationDate = now
			print("[Teximo] HotkeyManager: Triggering Control+Shift callback")
			callbacks.onControlShift?()
		}
	}
}