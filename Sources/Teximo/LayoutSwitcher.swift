import Cocoa
import Carbon

enum LayoutSwitcher {
	// Switch by simulating the system "Select the previous input source" shortcut.
	// This avoids programmatically enabling third-party sources (and avoids repeated consent dialog).
	static func cycleTo(targetInputIdSubstring: String, maxSteps: Int = 5) {
		print("[Teximo] LayoutSwitcher.cycleTo called with target: \(targetInputIdSubstring)")
		let logPath = "/tmp/teximo_debug.log"
		let logMessage = "[Teximo] LayoutSwitcher.cycleTo called with target: \(targetInputIdSubstring)\n"
		try? logMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
		
		// Ensure we're on the main thread for UI operations
		guard Thread.isMainThread else {
			print("[Teximo] LayoutSwitcher: Not on main thread, dispatching to main queue")
			let logMessage2 = "[Teximo] LayoutSwitcher: Not on main thread, dispatching to main queue\n"
			try? logMessage2.write(toFile: logPath, atomically: true, encoding: .utf8)
			DispatchQueue.main.async {
				cycleTo(targetInputIdSubstring: targetInputIdSubstring, maxSteps: maxSteps)
			}
			return
		}
		
		guard AccessibilityHelper.ensurePermission(promptIfNeeded: false) else { 
			print("[Teximo] LayoutSwitcher: No accessibility permission")
			let logMessage3 = "[Teximo] LayoutSwitcher: No accessibility permission\n"
			try? logMessage3.write(toFile: logPath, atomically: true, encoding: .utf8)
			return 
		}
		print("[Teximo] LayoutSwitcher: Starting layout cycling...")
		let logMessage4 = "[Teximo] LayoutSwitcher: Starting layout cycling...\n"
		try? logMessage4.write(toFile: logPath, atomically: true, encoding: .utf8)
		
		for i in 0..<maxSteps {
			print("[Teximo] LayoutSwitcher: Step \(i + 1)/\(maxSteps)")
			let logMessage5 = "[Teximo] LayoutSwitcher: Step \(i + 1)/\(maxSteps)\n"
			try? logMessage5.write(toFile: logPath, atomically: true, encoding: .utf8)
			
			if currentSourceMatches(substring: targetInputIdSubstring) { 
				print("[Teximo] LayoutSwitcher: Found target layout, stopping")
				let logMessage6 = "[Teximo] LayoutSwitcher: Found target layout, stopping\n"
				try? logMessage6.write(toFile: logPath, atomically: true, encoding: .utf8)
				return 
			}
			// Default macOS shortcut is Control+Space or Cmd+Space depending on user settings.
			// We send Control+Space here. Users can adjust system shortcut, but Control+Space usually remains bound to cycling.
			let spaceKey: CGKeyCode = 49
			print("[Teximo] LayoutSwitcher: Sending Control+Space keystroke")
			let logMessage7 = "[Teximo] LayoutSwitcher: Sending Control+Space keystroke\n"
			try? logMessage7.write(toFile: logPath, atomically: true, encoding: .utf8)
			AccessibilityHelper.performKeystroke(keyCode: spaceKey, flags: .maskControl)
			usleep(200_000)
		}
		print("[Teximo] LayoutSwitcher: Completed cycling")
		let logMessage8 = "[Teximo] LayoutSwitcher: Completed cycling\n"
		try? logMessage8.write(toFile: logPath, atomically: true, encoding: .utf8)
	}

	static func currentSourceMatches(substring: String) -> Bool {
		print("[Teximo] LayoutSwitcher.currentSourceMatches called with substring: \(substring)")
		let logPath = "/tmp/teximo_debug.log"
		let logMessage = "[Teximo] LayoutSwitcher.currentSourceMatches called with substring: \(substring)\n"
		try? logMessage.write(toFile: logPath, atomically: true, encoding: .utf8)
		
		// Ensure we're on the main thread for UI operations
		guard Thread.isMainThread else {
			print("[Teximo] LayoutSwitcher: Not on main thread, dispatching to main queue")
			let logMessage2 = "[Teximo] LayoutSwitcher: Not on main thread, dispatching to main queue\n"
			try? logMessage2.write(toFile: logPath, atomically: true, encoding: .utf8)
			var result = false
			DispatchQueue.main.sync {
				result = currentSourceMatches(substring: substring)
			}
			return result
		}
		
		do {
			guard let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { 
				print("[Teximo] LayoutSwitcher: Failed to get current input source")
				let logMessage2 = "[Teximo] LayoutSwitcher: Failed to get current input source\n"
				try? logMessage2.write(toFile: logPath, atomically: true, encoding: .utf8)
				return false 
			}
			print("[Teximo] LayoutSwitcher: Got current input source")
			let logMessage3 = "[Teximo] LayoutSwitcher: Got current input source\n"
			try? logMessage3.write(toFile: logPath, atomically: true, encoding: .utf8)
			
			if let id = TISGetInputSourceProperty(current, kTISPropertyInputSourceID) {
				let str = id as! CFString as String
				print("[Teximo] LayoutSwitcher: Current input source ID: \(str)")
				let logMessage4 = "[Teximo] LayoutSwitcher: Current input source ID: \(str)\n"
				try? logMessage4.write(toFile: logPath, atomically: true, encoding: .utf8)
				
				let matches = str.localizedCaseInsensitiveContains(substring)
				print("[Teximo] LayoutSwitcher: Matches '\(substring)': \(matches)")
				let logMessage5 = "[Teximo] LayoutSwitcher: Matches '\(substring)': \(matches)\n"
				try? logMessage5.write(toFile: logPath, atomically: true, encoding: .utf8)
				return matches
			}
			print("[Teximo] LayoutSwitcher: Failed to get input source ID")
			let logMessage6 = "[Teximo] LayoutSwitcher: Failed to get input source ID\n"
			try? logMessage6.write(toFile: logPath, atomically: true, encoding: .utf8)
			return false
		} catch {
			print("[Teximo] LayoutSwitcher: Error in currentSourceMatches: \(error)")
			let logMessage7 = "[Teximo] LayoutSwitcher: Error in currentSourceMatches: \(error)\n"
			try? logMessage7.write(toFile: logPath, atomically: true, encoding: .utf8)
			return false
		}
	}
}

