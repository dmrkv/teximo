import Cocoa

final class SimpleHotkeyDetector {
    private var eventMonitor: Any?
    private var onCmdShift: (() -> Void)?
    
    func start(onCmdShift: @escaping () -> Void) {
        print("[Teximo] SimpleHotkeyDetector: Starting")
        self.onCmdShift = onCmdShift
        
        // Use a simple approach - monitor for key down events
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            self?.handleEvent(event)
        }
        
        print("[Teximo] SimpleHotkeyDetector: Started")
    }
    
    func stop() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private func handleEvent(_ event: NSEvent) {
        // Check if Cmd+Shift is pressed
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hasCmd = flags.contains(.command)
        let hasShift = flags.contains(.shift)
        
        if hasCmd && hasShift {
            print("[Teximo] SimpleHotkeyDetector: Cmd+Shift detected")
            onCmdShift?()
        }
    }
}

