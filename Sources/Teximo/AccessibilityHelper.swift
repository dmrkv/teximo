import Cocoa
import ApplicationServices

enum AccessibilityHelper {
    static func ensurePermission(promptIfNeeded: Bool = true) -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: promptIfNeeded]
        let trusted = AXIsProcessTrustedWithOptions(options)
        return trusted
    }

    static func performKeystroke(keyCode: CGKeyCode, flags: CGEventFlags = []) {
        guard ensurePermission(promptIfNeeded: false) else { return }
        let src = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
        down?.flags = flags
        down?.post(tap: .cghidEventTap)
        let up = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        up?.flags = flags
        up?.post(tap: .cghidEventTap)
    }

    static func typeKeySequence(_ keyCodes: [CGKeyCode], flags: CGEventFlags = []) {
        for code in keyCodes { performKeystroke(keyCode: code, flags: flags) }
    }
}
 

