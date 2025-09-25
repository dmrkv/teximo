import Cocoa

final class SimpleLayoutSwitcher {
    static func switchLayout() {
        print("[Teximo] SimpleLayoutSwitcher: Switching layout")
        
        // Just use the system's built-in layout switching
        // This is the same as pressing Control+Space or Cmd+Space
        let spaceKey: CGKeyCode = 49
        
        // Try Control+Space first (most common)
        AccessibilityHelper.performKeystroke(keyCode: spaceKey, flags: .maskControl)
        
        print("[Teximo] SimpleLayoutSwitcher: Layout switch command sent")
    }
}

