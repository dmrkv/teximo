import Cocoa

enum TextActions {
	static func replaceSelection(with text: String) {
		let pasteboard = NSPasteboard.general
		let saved = pasteboard.string(forType: .string) ?? ""
		pasteboard.clearContents()
		pasteboard.setString(text, forType: .string)

		// Copy, replace with paste
		AccessibilityHelper.performKeystroke(keyCode: 8, flags: .maskCommand) // C
		usleep(100_000)
		AccessibilityHelper.performKeystroke(keyCode: 9, flags: .maskCommand) // V

		// Restore clipboard after slight delay
		dispatchAfter(0.2) {
			pasteboard.clearContents()
			pasteboard.setString(saved, forType: .string)
		}
	}

	static func getSelectionStringViaClipboard() -> String? {
		let pasteboard = NSPasteboard.general
		let saved = pasteboard.string(forType: .string) ?? ""
		AccessibilityHelper.performKeystroke(keyCode: 8, flags: .maskCommand) // Cmd+C
		usleep(120_000)
		let selection = pasteboard.string(forType: .string)
		// Restore
		dispatchAfter(0.2) {
			pasteboard.clearContents()
			pasteboard.setString(saved, forType: .string)
		}
		return selection
	}

	private static func dispatchAfter(_ seconds: TimeInterval, block: @escaping () -> Void) {
		DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: block)
	}
}


