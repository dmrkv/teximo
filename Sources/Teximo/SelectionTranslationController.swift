import Cocoa
import SwiftUI
import Translation

/// Owns a complete pasteboard snapshot, including images, files and custom formats.
struct PasteboardSnapshot {
    let items: [[NSPasteboard.PasteboardType: Data]]
    init(_ pasteboard: NSPasteboard) {
        items = (pasteboard.pasteboardItems ?? []).map { item in
            var values: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types { if let data = item.data(forType: type) { values[type] = data } }
            return values
        }
    }
    func restore(to pasteboard: NSPasteboard, ifUnchanged changeCount: Int) {
        guard pasteboard.changeCount == changeCount else { return }
        let restored = items.map { values -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in values { item.setData(data, forType: type) }
            return item
        }
        pasteboard.clearContents()
        if !restored.isEmpty { pasteboard.writeObjects(restored) }
    }
}

struct EditableSelection {
    let pid: pid_t
    let element: AXUIElement
    let text: String
    let range: CFRange?
    let fullValue: String?

    static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
    static func focusedElement(pid: pid_t) -> AXUIElement? {
        guard let value = attribute(AXUIElementCreateApplication(pid), kAXFocusedUIElementAttribute),
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }
    static func selectedRange(_ element: AXUIElement) -> CFRange? {
        guard let value = attribute(element, kAXSelectedTextRangeAttribute), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let axValue = value as! AXValue
        guard AXValueGetType(axValue) == .cfRange else { return nil }
        var range = CFRange()
        return AXValueGetValue(axValue, .cfRange, &range) ? range : nil
    }
    static func selectedText(_ element: AXUIElement) -> String? {
        if let text = attribute(element, kAXSelectedTextAttribute) as? String { return text }
        if let range = selectedRange(element), let value = attribute(element, kAXValueAttribute) as? String {
            return substring(value, range: range)
        }
        return nil
    }
    static func substring(_ value: String, range: CFRange) -> String? {
        let string = value as NSString
        guard range.location >= 0, range.length > 0, range.location <= string.length,
              range.length <= string.length - range.location else { return nil }
        return string.substring(with: NSRange(location: range.location, length: range.length))
    }
    static func capture() -> EditableSelection? {
        guard AccessibilityHelper.ensurePermission(promptIfNeeded: false),
              let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              let element = focusedElement(pid: app.processIdentifier) else { return nil }
        let role = attribute(element, kAXRoleAttribute) as? String
        let subrole = attribute(element, kAXSubroleAttribute) as? String
        guard subrole != kAXSecureTextFieldSubrole else { return nil }
        var settable = DarwinBoolean(false)
        AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &settable)
        guard settable.boolValue || [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(role ?? ""),
              let text = selectedText(element), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return EditableSelection(pid: app.processIdentifier, element: element, text: text,
                                 range: selectedRange(element), fullValue: attribute(element, kAXValueAttribute) as? String)
    }
    func isUnchanged() -> Bool {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid,
              let focused = Self.focusedElement(pid: pid), CFEqual(focused, element),
              Self.selectedText(element) == text else { return false }
        if let range {
            guard let current = Self.selectedRange(element), current.location == range.location, current.length == range.length else { return false }
        }
        if let fullValue, Self.attribute(element, kAXValueAttribute) as? String != fullValue { return false }
        return true
    }
}

@MainActor
final class SelectionTranslationController {
    private var panel: NSPanel?
    private var currentID: UUID?
    private var interactionRevision = 0
    private var busy = false
    var onOpenSettings: (() -> Void)?

    func selectionMayHaveChanged() { interactionRevision += 1 }

    func translateSelection() {
        guard #available(macOS 15, *) else {
            showMessage("Native translation requires macOS 15 or later.")
            return
        }
        guard !busy else { NSSound.beep(); return }
        guard AccessibilityHelper.ensurePermission(promptIfNeeded: false) else {
            showMessage("Allow Teximo in System Settings → Privacy & Security → Accessibility to translate selected text.")
            return
        }
        guard let selection = EditableSelection.capture() else {
            showMessage("Select text in an editable field, then press the translation shortcut again. Password fields and apps that do not expose their selection to Accessibility are not supported.")
            return
        }
        let settings = TeximoSettings.shared
        guard settings.translationSource != settings.translationTarget else {
            showMessage("Choose different source and target languages in Teximo Settings.")
            return
        }
        let id = UUID()
        currentID = id; busy = true
        let revision = interactionRevision
        let direction = TranslationLanguages.direction(for: selection.text, first: settings.translationSource, second: settings.translationTarget)
        let source = direction.source
        let target = direction.target
        let model = TranslationProgress()
        model.cancel = { [weak self, weak model] in
            // Updating the configuration cancels the view-owned task and its session.
            model?.configuration = nil
            self?.currentID = nil; self?.busy = false; self?.panel?.orderOut(nil)
        }
        model.sourceIdentifier = source
        model.activateForDownload = { [weak self] in
            guard self?.currentID == id else { return }
            self?.busy = true
            self?.revealPanel()
            NSApp.activate(ignoringOtherApps: true)
            self?.panel?.makeKeyAndOrderFront(nil)
        }
        model.openSettings = { [weak self, weak model] in
            model?.cancel?()
            self?.onOpenSettings?()
        }
        model.becameIdle = { [weak self] in
            guard self?.currentID == id else { return }
            self?.busy = false
            self?.revealPanel()
        }
        let view = TranslationProgressView(model: model, text: selection.text, target: target) { [weak self, weak model] result in
            guard let self, let model, self.currentID == id else { return }
            switch result {
            case .success(let translated):
                if translated == selection.text {
                    self.busy = false; model.busy = false
                    DispatchQueue.main.async { [weak self] in
                        guard self?.currentID == id else { return }
                        self?.panel?.orderOut(nil)
                    }
                    return
                }
                if self.interactionRevision == revision, selection.isUnchanged() {
                    self.paste(translated, selection: selection, revision: revision, model: model)
                } else {
                    self.busy = false
                    model.output = translated
                    model.message = "Your selection changed. Copy the translation when you're ready."
                    model.busy = false
                    self.revealPanel()
                }
            case .failure:
                self.busy = false; model.busy = false
                self.revealPanel()
            }
        }
        // Keep the SwiftUI host mounted for the lifetime of Apple's translation
        // session. An invisible, nonactivating host lets the task run on macOS 15+
        // without showing progress or taking focus from the selected text.
        present(view, silently: true)
    }

    @available(macOS 15, *)
    private func paste(_ text: String, selection: EditableSelection, revision: Int, model: TranslationProgress) {
        // Recheck immediately before posting the paste, after the asynchronous translation.
        guard interactionRevision == revision, selection.isUnchanged() else {
            busy = false; model.busy = false; model.output = text
            model.message = "Your selection changed. Copy the translation when you're ready."
            revealPanel()
            return
        }
        let pasteboard = NSPasteboard.general
        let saved = PasteboardSnapshot(pasteboard)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let changeCount = pasteboard.changeCount
        let id = currentID
        AccessibilityHelper.performKeystroke(keyCode: 9, flags: .maskCommand)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            saved.restore(to: pasteboard, ifUnchanged: changeCount)
            guard self?.currentID == id else { return }
            self?.busy = false
            model.busy = false
            if let originalValue = selection.fullValue,
               EditableSelection.attribute(selection.element, kAXValueAttribute) as? String == originalValue {
                model.output = text
                model.message = "This app did not accept the paste. Copy the translation and paste it manually."
                self?.revealPanel()
            } else {
                model.message = "Translation pasted."
                // Run after the translationTask closure has returned.
                self?.panel?.orderOut(nil)
            }
        }
    }

    private func showMessage(_ message: String) {
        present(VStack(alignment: .leading, spacing: 16) {
            Label("Teximo Translation", systemImage: "translate").font(.headline)
            Text(message).fixedSize(horizontal: false, vertical: true)
            HStack { Spacer(); Button("Close") { [weak self] in self?.panel?.orderOut(nil) } }
        }.padding(22).frame(width: 370))
    }

    private func revealPanel() {
        panel?.ignoresMouseEvents = false
        panel?.alphaValue = 1
        panel?.orderFrontRegardless()
    }

    private func present<Content: View>(_ content: Content, silently: Bool = false) {
        panel?.orderOut(nil)
        let panel = NSPanel(contentRect: .zero, styleMask: [.titled, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "Teximo Translation"
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.level = .floating
        // Set these before ordering the host so even the first frame is invisible.
        panel.alphaValue = silently ? 0 : 1
        panel.ignoresMouseEvents = silently
        let hosting = NSHostingView(rootView: content)
        panel.contentView = hosting
        panel.setContentSize(hosting.fittingSize)
        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrameTopLeftPoint(NSPoint(x: frame.maxX - panel.frame.width - 24, y: frame.maxY - 24))
        }
        self.panel = panel
        panel.orderFrontRegardless()
    }
}

@available(macOS 15, *)
@MainActor
final class TranslationProgress: ObservableObject {
    @Published var configuration: TranslationSession.Configuration?
    @Published var message = "Checking translation languages…"
    @Published var output: String?
    @Published var busy = true
    @Published var needsDownload = false
    @Published var downloading = false
    @Published var canRetry = false
    var sourceIdentifier: String?
    var cancel: (() -> Void)?
    var activateForDownload: (() -> Void)?
    var openSettings: (() -> Void)?
    var becameIdle: (() -> Void)?
}

@available(macOS 15, *)
struct TranslationProgressView: View {
    @ObservedObject var model: TranslationProgress
    let text: String
    let target: String
    let complete: (Result<String, Error>) -> Void
    private var pairDescription: String {
        [model.sourceIdentifier, target].compactMap { $0 }.map { Locale.current.localizedString(forIdentifier: $0) ?? $0 }.joined(separator: " and ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: model.needsDownload ? "arrow.down.circle.fill" : "translate").foregroundStyle(.tint)
                Text(model.needsDownload ? "Download languages" : "Teximo Translation").font(.headline)
                Spacer()
                if model.busy { ProgressView().controlSize(.small) }
            }
            Text(model.message).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if model.needsDownload {
                Button(model.downloading ? "Downloading…" : "Download Languages…") {
                    guard let source = model.sourceIdentifier else { return }
                    model.activateForDownload?()
                    model.downloading = true; model.busy = true
                    model.message = "macOS will ask to download \(pairDescription)."
                    model.configuration = .init(source: Locale.Language(identifier: source), target: Locale.Language(identifier: target))
                }.disabled(model.busy)
                Button("Open Language & Region…") { TranslationLanguages.openSystemSettings() }.buttonStyle(.link)
                Text("Or open Translation Languages in macOS settings and click Download for \(pairDescription).")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if model.canRetry {
                HStack {
                    if model.configuration != nil {
                        Button("Try Again") { model.busy = true; model.canRetry = false; model.configuration?.invalidate() }
                    }
                    Button("Teximo Settings…") { model.openSettings?() }
                }.disabled(model.busy)
            }
            if let output = model.output {
                ScrollView { Text(output).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: 160)
                Button("Copy Translation") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(output, forType: .string)
                    model.cancel?()
                }
            }
            HStack { Spacer(); Button(model.busy ? "Cancel" : "Close") { model.cancel?() } }
        }.padding(22).frame(width: 370)
        .task {
            let supported = await TranslationLanguages.supportedIdentifiers()
            if model.sourceIdentifier == nil { model.sourceIdentifier = TranslationLanguages.detectedSource(in: text, supported: supported) }
            guard !Task.isCancelled else { return }
            guard let source = model.sourceIdentifier else {
                model.message = "Could not detect the source language. Choose your language pair in Teximo Settings and try again."
                model.canRetry = true; model.busy = false
                complete(.failure(TranslationError.unableToIdentifyLanguage))
                return
            }
            let status = await TranslationLanguages.availability(source: source, target: target)
            guard !Task.isCancelled else { return }
            switch status {
            case .needsDownload:
                model.needsDownload = true; model.busy = false
                model.message = "Download \(pairDescription) to translate on this Mac. After downloading, select your text and use the shortcut again."
                model.becameIdle?()
            case .installed:
                model.message = "Translating your selection…"
                model.configuration = .init(source: Locale.Language(identifier: source), target: Locale.Language(identifier: target))
            default:
                model.message = status == .sameLanguage ? "Choose two different translation languages in Teximo Settings." : "This language pair is not supported. Choose different languages in Teximo Settings."
                model.canRetry = true; model.busy = false
                complete(.failure(TranslationError.unsupportedLanguagePairing))
            }
        }
        .translationTask(model.configuration) { session in
            let downloading = model.downloading
            do {
                if downloading {
                    // prepareTranslation requires an explicit source. Never call it with nil.
                    try await session.prepareTranslation()
                    try Task.checkCancellation()
                    let status = await TranslationLanguages.availability(source: model.sourceIdentifier!, target: target)
                    model.needsDownload = status != .installed
                    model.message = status == .installed ? "Languages downloaded. Select your text and press the translation shortcut again." : "The download is still needed or in progress. You can check it in Language & Region → Translation Languages."
                    model.busy = false; model.downloading = false
                    model.configuration = nil
                    model.becameIdle?()
                } else {
                    // translate receives actual text and can identify it; no prepare call is needed here.
                    let result = try await session.translate(text)
                    try Task.checkCancellation()
                    complete(.success(result.targetText))
                }
            } catch {
                guard !Task.isCancelled else { return }
                if downloading {
                    model.message = "The language download could not finish. Check your connection, retry, or download \(pairDescription) in Language & Region → Translation Languages."
                    model.needsDownload = true; model.downloading = false
                    model.configuration = nil
                } else {
                    model.message = "Translation could not finish. \(error.localizedDescription)"
                    model.canRetry = true
                }
                complete(.failure(error))
            }
        }
    }
}
