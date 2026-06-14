import Cocoa
import UserNotifications

class NotchDetector {
    private static let warningShownKey = "TeximoNotchWarningShown"
    
    /// Check if we should show the notch warning
    static func shouldShowNotchWarning() -> Bool {
        // Don't show if already shown
        if UserDefaults.standard.bool(forKey: warningShownKey) {
            return false
        }
        
        // Only show on devices with a notch (MacBook Pro 14" and 16" from 2021+)
        return hasNotch()
    }
    
    /// Detect if the current Mac has a notch
    private static func hasNotch() -> Bool {
        guard let screen = NSScreen.main else { return false }
        
        // Get the visible frame (excludes menu bar and notch area)
        let visibleFrame = screen.visibleFrame
        let fullFrame = screen.frame
        
        // On notched Macs, there's additional space at the top beyond the standard menu bar
        // Standard menu bar is ~25 points, notch area adds more
        let topInset = fullFrame.maxY - visibleFrame.maxY
        
        // Notched Macs have a larger top inset (typically 32-37 points vs 25 for non-notch)
        // Also check if it's a built-in display (laptops only have notches)
        let isBuiltIn = screen.localizedName.contains("Built-in") || 
                       screen == NSScreen.main
        
        return isBuiltIn && topInset > 28
    }
    
    /// Show the notch warning notification
    static func showNotchWarning() {
        let center = UNUserNotificationCenter.current()
        
        // Request notification permission first
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            guard granted else {
                print("[Teximo] Notification permission not granted")
                return
            }
            
            // Create notification content
            let content = UNMutableNotificationContent()
            content.title = "Teximo is Running"
            content.body = "Teximo is active in your menu bar. If you don't see the icon, it might be hidden behind the notch. Try rearranging your menu bar items by ⌘-dragging them, or run Teximo again to open Settings."
            content.sound = .default
            
            // Create trigger (show immediately)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            
            // Create request
            let request = UNNotificationRequest(
                identifier: "teximo.notch.warning",
                content: content,
                trigger: trigger
            )
            
            // Schedule notification
            center.add(request) { error in
                if let error = error {
                    print("[Teximo] Error showing notch warning: \(error)")
                } else {
                    print("[Teximo] Notch warning notification scheduled")
                }
            }
        }
    }
    
    /// Mark the warning as shown (won't show again)
    static func markWarningShown() {
        UserDefaults.standard.set(true, forKey: warningShownKey)
        print("[Teximo] Notch warning marked as shown")
    }
    
    /// Reset the warning (for testing)
    static func resetWarning() {
        UserDefaults.standard.removeObject(forKey: warningShownKey)
        print("[Teximo] Notch warning reset")
    }
}
