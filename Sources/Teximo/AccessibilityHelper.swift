import Cocoa
import ApplicationServices

enum AccessibilityHelper {
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
        down?.flags = flags
        down?.post(tap: .cghidEventTap)
        let up = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
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
        
        guard result == .success else { return nil }
        let element = focusedElement as! AXUIElement
        
        // Try to get selected text
        var selectedText: AnyObject?
        result = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedText)
        
        if result == .success, let text = selectedText as? String, !text.isEmpty {
            return text
        }
        
        // Fallback: try getting selected text range
        var selectedTextRange: AnyObject?
        result = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedTextRange)
        if result == .success, let range = selectedTextRange {
            var value: AnyObject?
            result = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
            if result == .success, let fullText = value as? String {
                // Parse the range and extract selected text
                if let rangeDict = range as? [String: Any],
                   let loc = rangeDict["location"] as? Int,
                   let len = rangeDict["length"] as? Int,
                   loc >= 0, len > 0, loc + len <= fullText.count {
                    let startIndex = fullText.index(fullText.startIndex, offsetBy: loc)
                    let endIndex = fullText.index(startIndex, offsetBy: len)
                    return String(fullText[startIndex..<endIndex])
                }
            }
        }
        
        return nil
    }
    
    // Replace selected text using keyboard simulation (works universally in all apps)
    static func replaceSelectedText(with newText: String) -> Bool {
        guard ensurePermission(promptIfNeeded: false) else { return false }
        
        // Always use keyboard simulation for universal compatibility
        // This works in ALL apps including Slack, Antigravity, Figma, etc.
        // The Accessibility API claims success but doesn't actually work in many apps
        return replaceSelectedTextWithKeyboard(newText)
    }
    
    // Universal text replacement using keyboard simulation only (no Accessibility API required)
    // This works in ALL apps that accept keyboard input
    static func replaceSelectedTextWithKeyboard(_ newText: String) -> Bool {
        guard ensurePermission(promptIfNeeded: false) else { return false }
        
        // Save original clipboard
        let pasteboard = NSPasteboard.general
        let originalClipboard = pasteboard.string(forType: .string) ?? ""
        
        // Put transliterated text on clipboard
        pasteboard.clearContents()
        pasteboard.setString(newText, forType: .string)
        usleep(50_000) // Wait for clipboard to update
        
        // Paste with Cmd+V directly over selected text
        // When text is selected, Cmd+V automatically replaces it (no delete needed)
        performKeystroke(keyCode: 9, flags: .maskCommand) // Cmd+V
        usleep(100_000) // Wait for paste to complete
        
        // Restore original clipboard
        pasteboard.clearContents()
        pasteboard.setString(originalClipboard, forType: .string)
        
        return true
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
 

