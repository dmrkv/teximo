import Cocoa

@MainActor
enum TextActions {
    enum Outcome: Equatable {
        case completed, noSelection, cancelled
    }

    /// The closures also let tests model apps that expose selection only through Cmd+C.
    struct Environment {
        var pasteboard: NSPasteboard
        var selectedText: () -> String?
        var copy: () -> Void
        var paste: () -> Void
        var isContextCurrent: () -> Bool
        var wait: (Duration) async throws -> Void = { try await Task.sleep(for: $0) }

        static func live(isContextCurrent: @escaping () -> Bool) -> Environment {
            let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier
            let element = pid.flatMap { EditableSelection.focusedElement(pid: $0) }
            return Environment(pasteboard: .general, selectedText: { AccessibilityHelper.getSelectedText() },
                               copy: { AccessibilityHelper.performKeystroke(keyCode: 8, flags: .maskCommand) },
                               paste: { AccessibilityHelper.performKeystroke(keyCode: 9, flags: .maskCommand) },
                               isContextCurrent: {
                guard isContextCurrent(), let pid,
                      NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { return false }
                if let element {
                    guard let focused = EditableSelection.focusedElement(pid: pid), CFEqual(focused, element) else { return false }
                }
                return true
            })
        }
    }

    static func transformSelection(_ transform: (String) -> String, environment: Environment) async -> Outcome {
        guard environment.isContextCurrent() else { return .cancelled }
        let pasteboard = environment.pasteboard
        let saved = PasteboardSnapshot(pasteboard)
        var ownedChangeCount: Int?
        defer {
            if let ownedChangeCount { saved.restore(to: pasteboard, ifUnchanged: ownedChangeCount) }
        }

        let accessibleSelection = environment.selectedText().flatMap { $0.isEmpty ? nil : $0 }
        var selection = accessibleSelection
        if selection == nil {
            pasteboard.clearContents()
            let clearedChangeCount = pasteboard.changeCount
            ownedChangeCount = clearedChangeCount
            environment.copy()
            // Yield the main run loop so the event tap and the target app can deliver Cmd+C.
            // A clipboard change is the copy acknowledgement, even when its text equals the old clipboard.
            for _ in 0..<40 {
                do { try await environment.wait(.milliseconds(25)) } catch { return .cancelled }
                guard !Task.isCancelled, environment.isContextCurrent() else { return .cancelled }
                if pasteboard.changeCount != clearedChangeCount {
                    ownedChangeCount = pasteboard.changeCount
                    selection = pasteboard.string(forType: .string)
                    break
                }
            }
        }
        guard let selection, !selection.isEmpty else { return .noSelection }
        guard !Task.isCancelled, environment.isContextCurrent() else { return .cancelled }
        if let accessibleSelection, environment.selectedText() != accessibleSelection { return .cancelled }
        let transformed = transform(selection)
        guard transformed != selection else { return .completed }
        // Do not overwrite a new clipboard item copied by the user while we were waiting.
        if let ownedChangeCount, pasteboard.changeCount != ownedChangeCount { return .cancelled }
        pasteboard.clearContents()
        pasteboard.setString(transformed, forType: .string)
        ownedChangeCount = pasteboard.changeCount
        environment.paste()
        // Keep the replacement available until the queued paste has reached the other app.
        // Blocking this thread with usleep would stop our keyboard event tap from forwarding it.
        do { try await environment.wait(.milliseconds(400)) } catch { return .cancelled }
        return .completed
    }
}
