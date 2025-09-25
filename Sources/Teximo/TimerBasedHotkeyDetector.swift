import Cocoa

final class TimerBasedHotkeyDetector {
    private var timer: Timer?
    private var onCmdShift: (() -> Void)?
    private var lastFlags: NSEvent.ModifierFlags = []
    private var lastInvocationDate: Date = .distantPast
    private let debounceInterval: TimeInterval = 0.25
    
    func start(onCmdShift: @escaping () -> Void) {
        print("[Teximo] TimerBasedHotkeyDetector: Starting")
        self.onCmdShift = onCmdShift
        
        // Use a timer to check modifier keys periodically
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkModifierKeys()
        }
        
        // Ensure the timer is added to the main run loop
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
        
        print("[Teximo] TimerBasedHotkeyDetector: Started")
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkModifierKeys() {
        let currentFlags = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hasShift = currentFlags.contains(.shift)
        let hasCmd = currentFlags.contains(.command)
        
        // Debug logging
        if hasShift || hasCmd {
            print("[Teximo] TimerBasedHotkeyDetector: Modifier keys detected - Shift: \(hasShift), Cmd: \(hasCmd)")
        }
        
        // Only process when keys are pressed (not released)
        guard currentFlags != lastFlags else { return }
        
        lastFlags = currentFlags
        
        // Check if this is a key press (keys were added)
        let isKeyPress = (hasShift || hasCmd)
        
        if isKeyPress && hasShift && hasCmd {
            let now = Date()
            guard now.timeIntervalSince(lastInvocationDate) > debounceInterval else { return }
            
            lastInvocationDate = now
            print("[Teximo] TimerBasedHotkeyDetector: Cmd+Shift detected")
            onCmdShift?()
        }
    }
}
