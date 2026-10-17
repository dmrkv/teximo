import Cocoa

/// A small, testable state machine shared by all four global shortcuts.
struct ShortcutState {
    private var modifierCandidate: TeximoAction?
    private var pendingKeyAction: TeximoAction?
    private var keyWasUsed = false
    private var previousModifiers: NSEvent.ModifierFlags = []

    mutating func handle(type: NSEvent.EventType, flags: NSEvent.ModifierFlags,
                         keyCode: UInt16, isRepeat: Bool = false,
                         configurations: [(TeximoAction, HotkeyConfig)]) -> TeximoAction? {
        let modifiers = flags.intersection([.command, .option, .control, .shift])
        if type == .keyDown {
            modifierCandidate = nil
            keyWasUsed = true
            if !isRepeat {
                pendingKeyAction = configurations.first {
                    $0.1.enabled && $0.1.keyCode == keyCode && $0.1.matches(flags)
                }?.0
            }
        } else if type == .flagsChanged {
            // Caps Lock arrives as flagsChanged rather than keyDown.
            if keyCode == 57, flags.contains(.capsLock) {
                self = ShortcutState()
                return configurations.first { $0.1.enabled && $0.1.keyCode == 57 && $0.1.matches(flags) }?.0
            }
            if modifiers.isEmpty {
                let action = pendingKeyAction ?? modifierCandidate
                self = ShortcutState()
                return action
            }
            if !keyWasUsed, !modifiers.isSubset(of: previousModifiers) {
                modifierCandidate = configurations.first {
                    $0.1.keyCode == nil && $0.1.matches(flags)
                }?.0
            }
            previousModifiers = modifiers

        } else if type == .keyUp, modifiers.isEmpty {
            let action = pendingKeyAction
            self = ShortcutState()
            return action
        }
        return nil
    }
}

enum TeximoAction: String, CaseIterable, Identifiable {
    case layout, transliteration, caseToggle, translation
    var id: String { rawValue }
    var title: String {
        switch self {
        case .layout: return "Switch keyboard layout"
        case .transliteration: return "Transliterate selection"
        case .caseToggle: return "Change text case"
        case .translation: return "Translate selection"
        }
    }
    var subtitle: String {
        switch self {
        case .layout: return "Switch between your English and Russian layouts."
        case .transliteration: return "Convert Latin and Cyrillic characters."
        case .caseToggle: return "Cycle through lower, UPPER, Title and Sentence case."
        case .translation: return "Replace selected text with a native translation."
        }
    }
}

final class GlobalShortcutMonitor {
    private var monitor: Any?
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var swallowedKeys: Set<UInt16> = []
    private var state = ShortcutState()
    var onAction: ((TeximoAction) -> Void)?
    var onUserInteraction: (() -> Void)?

    var canHandleKeyShortcuts: Bool { tap != nil }

    private var configurations: [(TeximoAction, HotkeyConfig)] {
        TeximoAction.allCases.compactMap { action in
            TeximoSettings.shared.hotkey(for: action).map { (action, $0) }
        }
    }

    func start() {
        stop()
        let types: [CGEventType] = [.flagsChanged, .keyDown, .keyUp, .leftMouseDown, .rightMouseDown]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let manager = Unmanaged<GlobalShortcutMonitor>.fromOpaque(context).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = manager.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            guard event.getIntegerValueField(.eventSourceUserData) != AccessibilityHelper.syntheticEventTag,
                  let nativeEvent = NSEvent(cgEvent: event) else { return Unmanaged.passUnretained(event) }
            // Leave Settings and its shortcut recorder to AppKit.
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier {
                manager.state = ShortcutState()
                return Unmanaged.passUnretained(event)
            }
            let configs = manager.configurations
            var suppress = false
            if type == .keyDown {
                suppress = configs.contains { $0.1.enabled && $0.1.keyCode == nativeEvent.keyCode && $0.1.matches(nativeEvent.modifierFlags) }
                if suppress { manager.swallowedKeys.insert(nativeEvent.keyCode) }
            } else if type == .keyUp {
                suppress = manager.swallowedKeys.remove(nativeEvent.keyCode) != nil
            }
            manager.handle(nativeEvent, configurations: configs)
            return suppress ? nil : Unmanaged.passUnretained(event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        if let tap {
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            if let runLoopSource { CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
            CGEvent.tapEnable(tap: tap, enable: true)
        } else {
            // Preserve modifier-only tools if macOS temporarily refuses an event tap.
            // Key shortcuts need the tap so their key never reaches the text field.
            monitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown, .keyUp, .leftMouseDown, .rightMouseDown]) { [weak self] event in
                guard let self, event.cgEvent?.getIntegerValueField(.eventSourceUserData) != AccessibilityHelper.syntheticEventTag else { return }
                self.handle(event, configurations: self.configurations.filter { $0.1.keyCode == nil })
            }
            NSLog("[Teximo] Global key shortcuts unavailable. Check Accessibility permission and restart Teximo.")
        }
    }

    private func handle(_ event: NSEvent, configurations: [(TeximoAction, HotkeyConfig)]) {
        if event.type == .keyDown || event.type == .leftMouseDown || event.type == .rightMouseDown {
            onUserInteraction?()
        }
        if event.type == .leftMouseDown || event.type == .rightMouseDown {
            state = ShortcutState()
            return
        }
        if let action = state.handle(type: event.type, flags: event.modifierFlags,
                                     keyCode: event.keyCode, isRepeat: event.type == .keyDown && event.isARepeat,
                                     configurations: configurations) {
            // Keep the event tap responsive while text actions and system dialogs run.
            DispatchQueue.main.async { [weak self] in self?.onAction?(action) }
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        tap = nil; runLoopSource = nil
        swallowedKeys = []; state = ShortcutState()
    }
    deinit { stop() }
}
