import Cocoa

enum HotkeyAction: CaseIterable, Hashable {
    case switchLayout
    case transliterateText
    case toggleCase
}

enum HotkeyInvocationPhase: Equatable {
    case pressed
    case released
}

enum HotkeyInvocationSource: Equatable {
    case keyed
    case modifierOnly
}

struct HotkeyInvocation: Equatable {
    let action: HotkeyAction
    let phase: HotkeyInvocationPhase
    let source: HotkeyInvocationSource
}

enum HotkeyInputEventKind {
    case flagsChanged
    case keyDown
    case keyUp
}

struct HotkeyInputEvent {
    let kind: HotkeyInputEventKind
    let modifiers: Set<ModifierKey>
    let keyCode: UInt16?
    let isRepeat: Bool
}

enum HotkeyEventDisposition: Equatable {
    case passThrough
    case consume
}

struct HotkeyProcessingResult: Equatable {
    let disposition: HotkeyEventDisposition
    let invocations: [HotkeyInvocation]
}

/// Permission-free hotkey state machine used by the event tap and unit tests.
struct HotkeyEventProcessor {
    private var activeKeyCodes: [HotkeyAction: UInt16] = [:]
    private var activeModifierConfigs: [HotkeyAction: HotkeyConfig] = [:]

    mutating func process(
        _ event: HotkeyInputEvent,
        configurations: [HotkeyAction: HotkeyConfig]
    ) -> HotkeyProcessingResult {
        switch event.kind {
        case .keyDown:
            return processKeyDown(event, configurations: configurations)
        case .keyUp:
            return processKeyUp(event)
        case .flagsChanged:
            return processFlagsChanged(event, configurations: configurations)
        }
    }

    mutating func reset() {
        activeKeyCodes.removeAll()
        activeModifierConfigs.removeAll()
    }

    private mutating func processKeyDown(
        _ event: HotkeyInputEvent,
        configurations: [HotkeyAction: HotkeyConfig]
    ) -> HotkeyProcessingResult {
        guard let keyCode = event.keyCode else {
            return HotkeyProcessingResult(disposition: .passThrough, invocations: [])
        }

        // A matched physical key remains suppressed through auto-repeat, even if
        // its modifiers or saved configuration change while it is held.
        if activeKeyCodes.values.contains(keyCode) {
            return HotkeyProcessingResult(disposition: .consume, invocations: [])
        }

        let matchingActions = HotkeyAction.allCases.filter { action in
            guard let config = configurations[action], config.keyCode != nil else { return false }
            return config.matches(modifiers: event.modifiers, keyCode: keyCode)
        }

        guard !matchingActions.isEmpty else {
            return HotkeyProcessingResult(disposition: .passThrough, invocations: [])
        }

        // An auto-repeat first observed after startup is still consumed, but it
        // must not synthesize a new shortcut invocation.
        guard !event.isRepeat else {
            return HotkeyProcessingResult(disposition: .consume, invocations: [])
        }

        for action in matchingActions {
            activeKeyCodes[action] = keyCode
        }

        let invocations = matchingActions.map {
            HotkeyInvocation(action: $0, phase: .pressed, source: .keyed)
        }
        return HotkeyProcessingResult(disposition: .consume, invocations: invocations)
    }

    private mutating func processKeyUp(_ event: HotkeyInputEvent) -> HotkeyProcessingResult {
        guard let keyCode = event.keyCode else {
            return HotkeyProcessingResult(disposition: .passThrough, invocations: [])
        }

        let matchingActions = activeKeyCodes.compactMap { action, activeKeyCode in
            activeKeyCode == keyCode ? action : nil
        }
        guard !matchingActions.isEmpty else {
            return HotkeyProcessingResult(disposition: .passThrough, invocations: [])
        }

        for action in matchingActions {
            activeKeyCodes.removeValue(forKey: action)
        }

        // Keyed shortcuts invoke once on key-down. Their key-up is consumed only
        // to keep the foreground application from seeing half of the shortcut.
        return HotkeyProcessingResult(disposition: .consume, invocations: [])
    }

    private mutating func processFlagsChanged(
        _ event: HotkeyInputEvent,
        configurations: [HotkeyAction: HotkeyConfig]
    ) -> HotkeyProcessingResult {
        var invocations: [HotkeyInvocation] = []

        for action in HotkeyAction.allCases {
            if let activeConfig = activeModifierConfigs[action] {
                if configurations[action] != activeConfig {
                    activeModifierConfigs.removeValue(forKey: action)
                } else if !activeConfig.modifiers.isSubset(of: event.modifiers) {
                    activeModifierConfigs.removeValue(forKey: action)
                    invocations.append(
                        HotkeyInvocation(action: action, phase: .released, source: .modifierOnly)
                    )
                }
            }

            guard activeModifierConfigs[action] == nil,
                  let config = configurations[action],
                  config.keyCode == nil,
                  !config.modifiers.isEmpty,
                  config.matches(modifiers: event.modifiers, keyCode: nil) else {
                continue
            }

            activeModifierConfigs[action] = config
            invocations.append(
                HotkeyInvocation(action: action, phase: .pressed, source: .modifierOnly)
            )
        }

        // Caps Lock is recorded as key code 57 even though macOS reports it as a
        // flagsChanged event. Treat any exact keyed match here as one invocation.
        var matchedKeyedAction = false
        if let keyCode = event.keyCode {
            for action in HotkeyAction.allCases {
                guard let config = configurations[action],
                      config.keyCode != nil,
                      config.matches(modifiers: event.modifiers, keyCode: keyCode) else {
                    continue
                }
                matchedKeyedAction = true
                invocations.append(
                    HotkeyInvocation(action: action, phase: .pressed, source: .keyed)
                )
            }
        }

        // Modifier transitions pass through so foreground applications never see
        // an incomplete modifier sequence. A keyed flags event (notably Caps Lock)
        // is safe to consume as the complete shortcut event.
        return HotkeyProcessingResult(
            disposition: matchedKeyedAction ? .consume : .passThrough,
            invocations: invocations
        )
    }
}

final class HotkeyManager {
    typealias ConfigurationProvider = () -> [HotkeyAction: HotkeyConfig]
    typealias InvocationHandler = (HotkeyInvocation) -> Void

    private var eventTap: CFMachPort?
    private var eventRunLoop: CFRunLoop?
    private var eventThread: Thread?
    private var threadStopped: DispatchSemaphore?
    private var configurationProvider: ConfigurationProvider?
    private var invocationHandler: InvocationHandler?
    private var processor = HotkeyEventProcessor()
    private var suspended = false
    private var generation: UInt = 0
    private let stateLock = NSLock()

    var isSuspended: Bool {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return suspended
        }
        set {
            stateLock.lock()
            suspended = newValue
            if newValue {
                processor.reset()
            }
            stateLock.unlock()
        }
    }

    @discardableResult
    func start(
        configurations: @escaping ConfigurationProvider,
        onInvocation: @escaping InvocationHandler
    ) -> Bool {
        precondition(Thread.isMainThread, "HotkeyManager lifecycle must run on the main thread")
        stop()
        stateLock.lock()
        generation &+= 1
        configurationProvider = configurations
        invocationHandler = onInvocation
        stateLock.unlock()

        let eventTypes: [CGEventType] = [.flagsChanged, .keyDown, .keyUp]
        let eventMask = eventTypes.reduce(CGEventMask(0)) { mask, type in
            mask | (CGEventMask(1) << type.rawValue)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, type, event, userInfo in
                guard let userInfo else {
                    return Unmanaged.passUnretained(event)
                }
                let manager = Unmanaged<HotkeyManager>
                    .fromOpaque(userInfo)
                    .takeUnretainedValue()
                return manager.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            stateLock.lock()
            configurationProvider = nil
            invocationHandler = nil
            stateLock.unlock()
            print("[Teximo] Failed to create suppressing hotkey event tap")
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            stateLock.lock()
            configurationProvider = nil
            invocationHandler = nil
            stateLock.unlock()
            print("[Teximo] Failed to create hotkey event tap run-loop source")
            return false
        }

        let started = DispatchSemaphore(value: 0)
        let stopped = DispatchSemaphore(value: 0)
        let thread = Thread { [weak self] in
            autoreleasepool {
                defer { stopped.signal() }
                let runLoop = CFRunLoopGetCurrent()
                if let manager = self {
                    manager.stateLock.lock()
                    manager.eventRunLoop = runLoop
                    manager.stateLock.unlock()
                }

                CFRunLoopAddSource(runLoop, source, .commonModes)
                CGEvent.tapEnable(tap: tap, enable: true)
                started.signal()
                CFRunLoopRun()
                CFRunLoopRemoveSource(runLoop, source, .commonModes)
            }
        }
        thread.name = "Teximo Hotkey Event Tap"

        stateLock.lock()
        eventTap = tap
        eventThread = thread
        threadStopped = stopped
        stateLock.unlock()

        thread.start()
        started.wait()
        print("[Teximo] Suppressing hotkey event tap installed")
        return true
    }

    func stop() {
        precondition(Thread.isMainThread, "HotkeyManager lifecycle must run on the main thread")
        stateLock.lock()
        let tap = eventTap
        let runLoop = eventRunLoop
        let thread = eventThread
        let stopped = threadStopped
        eventTap = nil
        eventRunLoop = nil
        eventThread = nil
        threadStopped = nil
        configurationProvider = nil
        invocationHandler = nil
        suspended = false
        generation &+= 1
        processor.reset()
        stateLock.unlock()

        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoop {
            CFRunLoopStop(runLoop)
            CFRunLoopWakeUp(runLoop)
        }
        if let tap {
            CFMachPortInvalidate(tap)
        }
        if let thread, let stopped, Thread.current !== thread {
            stopped.wait()
        }
    }

    deinit {
        stop()
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            stateLock.lock()
            processor.reset()
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            stateLock.unlock()
            return Unmanaged.passUnretained(event)
        }

        guard event.getIntegerValueField(.eventSourceUnixProcessID) != Int64(ProcessInfo.processInfo.processIdentifier),
              let kind = inputKind(for: type) else {
            return Unmanaged.passUnretained(event)
        }

        let input = HotkeyInputEvent(
            kind: kind,
            modifiers: modifierKeys(from: event.flags),
            keyCode: UInt16(event.getIntegerValueField(.keyboardEventKeycode)),
            isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        )

        stateLock.lock()
        guard !suspended, let configurationProvider else {
            stateLock.unlock()
            return Unmanaged.passUnretained(event)
        }
        let result = processor.process(input, configurations: configurationProvider())
        let invocationHandler = self.invocationHandler
        let invocationGeneration = generation
        stateLock.unlock()

        if let invocationHandler {
            for invocation in result.invocations {
                DispatchQueue.main.async { [weak self] in
                    guard self?.canDeliverInvocation(for: invocationGeneration) == true else {
                        return
                    }
                    invocationHandler(invocation)
                }
            }
        }

        return Self.tapReturnValue(for: result.disposition, event: event)
    }

    static func tapReturnValue(
        for disposition: HotkeyEventDisposition,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        switch disposition {
        case .passThrough:
            return Unmanaged.passUnretained(event)
        case .consume:
            return nil
        }
    }

    private func canDeliverInvocation(for invocationGeneration: UInt) -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return generation == invocationGeneration && !suspended && invocationHandler != nil
    }

    private func inputKind(for type: CGEventType) -> HotkeyInputEventKind? {
        switch type {
        case .flagsChanged: return .flagsChanged
        case .keyDown: return .keyDown
        case .keyUp: return .keyUp
        default: return nil
        }
    }

    private func modifierKeys(from flags: CGEventFlags) -> Set<ModifierKey> {
        var modifiers = Set<ModifierKey>()
        if flags.contains(.maskCommand) { modifiers.insert(.command) }
        if flags.contains(.maskShift) { modifiers.insert(.shift) }
        if flags.contains(.maskAlternate) { modifiers.insert(.option) }
        if flags.contains(.maskControl) { modifiers.insert(.control) }
        return modifiers
    }
}
