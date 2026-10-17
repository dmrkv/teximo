import Cocoa
import ApplicationServices

enum AccessibilityHelper {
    static let syntheticEventTag: Int64 = 0x544558494D4F
    static func ensurePermission(promptIfNeeded: Bool = true) -> Bool {
        // Access kAXTrustedCheckOptionPrompt outside concurrency context
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options: NSDictionary = [key: promptIfNeeded]
        let trusted = AXIsProcessTrustedWithOptions(options)
        return trusted
    }

    static func performKeystroke(keyCode: CGKeyCode, flags: CGEventFlags = []) {
        guard ensurePermission(promptIfNeeded: false) else { return }
        let src = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
        down?.setIntegerValueField(.eventSourceUserData, value: syntheticEventTag)
        down?.flags = flags
        down?.post(tap: .cghidEventTap)
        let up = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        up?.setIntegerValueField(.eventSourceUserData, value: syntheticEventTag)
        up?.flags = flags
        up?.post(tap: .cghidEventTap)
    }

    static func typeKeySequence(_ keyCodes: [CGKeyCode], flags: CGEventFlags = []) {
        for code in keyCodes { performKeystroke(keyCode: code, flags: flags) }
    }
    
    // Get selected text using Accessibility API (no clipboard)
    static func getSelectedText() -> String? {
        guard ensurePermission(promptIfNeeded: false) else { return nil }
        
        // Get the currently focused UI element
        guard let focusedApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = focusedApp.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)
        
        var focusedElement: AnyObject?
        var result = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        if result != .success {
            // Try getting the focused window first
            var focusedWindow: AnyObject?
            result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)
            if result == .success, let window = focusedWindow {
                let windowElement = window as! AXUIElement
                result = AXUIElementCopyAttributeValue(windowElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
            }
        }
        
        guard result == .success, let focusedElement,
              CFGetTypeID(focusedElement) == AXUIElementGetTypeID() else { return nil }
        return EditableSelection.selectedText(focusedElement as! AXUIElement)
    }

    // Type a Unicode string character by character using CGEvent
    // Made public so it can be used by keyboard simulation fallback
    static func typeUnicodeString(_ text: String) {
        let src = CGEventSource(stateID: .hidSystemState)
        // Convert to UTF-16 for keyboardSetUnicodeString (UniChar is UInt16)
        let utf16 = text.utf16
        for char in utf16 {
            var unicodeChar: UInt16 = char
            // Create a keyboard event with Unicode
            let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false)
            
            // Set Unicode character using the correct API (UniChar is UInt16)
            keyDown?.keyboardSetUnicodeString(stringLength: 1, unicodeString: &unicodeChar)
            keyUp?.keyboardSetUnicodeString(stringLength: 1, unicodeString: &unicodeChar)
            
            keyDown?.post(tap: .cghidEventTap)
            usleep(15_000) // 15ms between keystrokes for reliability
            keyUp?.post(tap: .cghidEventTap)
        }
    }
}
 

