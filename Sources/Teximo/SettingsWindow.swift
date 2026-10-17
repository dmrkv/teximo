import Cocoa
import SwiftUI
import ServiceManagement
import Translation

final class SettingsWindow: NSWindow {
    var onMenuBarVisibilityChanged: (() -> Void)?
    var onSettingsChanged: (() -> Void)?
    private let model: SettingsModel

    func showShortcutPermissionError() {
        model.error = "macOS could not enable global key shortcuts. Check Teximo’s Accessibility permission and restart the app."
    }

    init(model: SettingsModel? = nil, initialPage: SettingsPage = .general) {
        let model = model ?? SettingsModel()
        self.model = model
        super.init(contentRect: NSRect(x: 0, y: 0, width: 760, height: 540),
                   styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        title = "Teximo Settings"
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isOpaque = false
        backgroundColor = .clear
        minSize = NSSize(width: 720, height: 500)
        isReleasedWhenClosed = false
        model.onChange = { [weak self] in
            self?.onMenuBarVisibilityChanged?()
            self?.onSettingsChanged?()
        }
        let hosting = NSHostingView(rootView: TeximoSettingsView(model: model, initialPage: initialPage))
        hosting.sizingOptions = []
        contentView = hosting
        center()
    }
}

@MainActor
final class SettingsModel: ObservableObject {
    @Published var revision = 0
    @Published var languages: [String] = []
    @Published var downloadAvailability: LanguageDownloadAvailability = .checking
    @Published var downloadIssue: String?
    @Published var error: String?
    var onChange: (() -> Void)?
    let settings: TeximoSettings

    init(settings: TeximoSettings = .shared) {
        self.settings = settings
    }
    func changed() { revision += 1; onChange?() }
    var sourceForDownload: String { settings.translationSource }
    var pairDescription: String { "\(Self.languageName(sourceForDownload)) ↔ \(Self.languageName(settings.translationTarget))" }

    func save(_ config: HotkeyConfig?, for action: TeximoAction) {
        if let config, TeximoAction.allCases.contains(where: { $0 != action && settings.hotkey(for: $0) == config }) {
            error = "This shortcut is already used by another action. Choose a different combination."
            return
        }
        settings.setHotkey(config, for: action)
        changed()
    }

    func refreshLanguages() async {
        guard #available(macOS 15, *) else { downloadAvailability = .unavailable; return }
        if languages.isEmpty {
            languages = await TranslationLanguages.supportedIdentifiers().sorted {
                Self.languageName($0).localizedCaseInsensitiveCompare(Self.languageName($1)) == .orderedAscending
            }
        }
        let source = sourceForDownload
        let target = settings.translationTarget
        guard languages.contains(source), languages.contains(target) else { downloadAvailability = .unsupported; return }
        let status = await TranslationLanguages.availability(source: source, target: target)
        guard source == sourceForDownload, target == settings.translationTarget else { return }
        downloadAvailability = status
        if status == .installed { downloadIssue = nil }
    }

    static func languageName(_ id: String) -> String { Locale.current.localizedString(forIdentifier: id) ?? id }
}

enum SettingsPage: String, CaseIterable, Identifiable {
    case general = "General"
    case transliteration = "Transliteration"
    case translation = "Translation"
    case shortcuts = "Shortcuts"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .transliteration: return "keyboard"
        case .translation: return "translate"
        case .shortcuts: return "command"
        }
    }
}

/// A semantic macOS material blends the desktop behind the sidebar and honors
/// the system appearance and accessibility transparency preferences.
private struct SettingsSidebarMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

private struct SettingsAppIcon: NSViewRepresentable {
    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        // Ask macOS for the same app icon that Finder uses, including its
        // system treatment and the representation suited to the display scale.
        view.image = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
        view.imageScaling = .scaleProportionallyUpOrDown
        return view
    }
    func updateNSView(_ view: NSImageView, context: Context) {}
}

struct TeximoSettingsView: View {
    @ObservedObject var model: SettingsModel
    @Environment(\.displayScale) private var displayScale
    @State private var page: SettingsPage?
    @State private var resetConfirmation = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    init(model: SettingsModel, initialPage: SettingsPage = .general) {
        self.model = model
        self._page = State(initialValue: initialPage)
    }

    private var selectedPage: SettingsPage { page ?? .general }
    var body: some View {
        HStack(spacing: 0) {
            sidebar
            VStack(alignment: .leading, spacing: 0) {
                Text(selectedPage.rawValue)
                    .font(.system(size: 23, weight: .semibold))
                    .padding(.horizontal, 24).padding(.top, 52).padding(.bottom, 4)
                Group {
                    switch selectedPage {
                    case .general: general
                    case .transliteration: transliteration
                    case .translation: translation
                    case .shortcuts: shortcuts
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                HStack {
                    Spacer()
                    Button("Reset to Defaults…") { resetConfirmation = true }.controlSize(.small)
                }.padding(.horizontal, 24).padding(.bottom, 18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
            // Draw a single physical pixel over the opaque detail background.
            // A separate Divider leaves a transparent seam between the panes.
            .overlay(alignment: .leading) {
                Color(nsColor: .separatorColor).frame(width: 1 / displayScale)
            }
        }
        .ignoresSafeArea()
        .alert("Unable to update settings", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK", role: .cancel) { model.error = nil }
        } message: { Text(model.error ?? "") }
        .confirmationDialog("Reset shortcuts, keyboard layouts and translation preferences?", isPresented: $resetConfirmation) {
            Button("Reset to Defaults", role: .destructive) { model.settings.resetToDefaults(); model.changed() }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                SettingsAppIcon()
                    .frame(width: 44, height: 44).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Teximo").font(.system(size: 18, weight: .semibold))
                    Text("Settings").font(.callout).foregroundStyle(.secondary)
                }
            }.padding(.horizontal, 18).padding(.top, 52).padding(.bottom, 22)
            List(selection: $page) {
                ForEach(SettingsPage.allCases) { item in
                    Label(item.rawValue, systemImage: item.symbol)
                        .font(.system(size: 13))
                        .padding(.vertical, 5)
                        .tag(item)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .accessibilityLabel("Settings pages")
            Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development")")
                .font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, 20).padding(.bottom, 20)
        }
        .frame(width: 200)
        .frame(maxHeight: .infinity)
        .background(SettingsSidebarMaterial())
    }

    private var shortcuts: some View {
        Form {
            Section {
                ForEach(TeximoAction.allCases) { action in
                    HStack {
                        Text(action.title)
                        Spacer()
                        ShortcutRecorder(config: model.settings.hotkey(for: action)) { model.save($0, for: action) }
                            .frame(width: 125, height: 28)
                        Button { model.save(nil, for: action) } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }
                            .buttonStyle(.plain).disabled(model.settings.hotkey(for: action) == nil)
                            .help("Disable \(action.title.lowercased())")
                    }.padding(.vertical, 2)
                }
            } header: {
                Text("Keyboard shortcuts")
            } footer: {
                Text("Click to record. Press Escape to cancel. Shortcuts run when you release the keys.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
    }

    private var general: some View {
        Form {
            Section("Startup & appearance") {
                Toggle("Launch at login", isOn: Binding(get: { launchAtLogin }, set: { enabled in
                    do {
                        if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                        UserDefaults.standard.set(enabled, forKey: "TeximoStartupEnabled")
                        if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
                    } catch { model.error = error.localizedDescription }
                }))
                Toggle("Show in menu bar", isOn: Binding(get: { model.settings.showMenuBarIcon }, set: {
                    model.settings.showMenuBarIcon = $0; model.changed()
                }))
            }
            if !AccessibilityHelper.ensurePermission(promptIfNeeded: false) {
                Section("Permissions") {
                    HStack {
                        Label("Accessibility permission needed", systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                        Spacer()
                        Button("Open Settings…") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                        }
                    }
                }
            }
        }.formStyle(.grouped)
    }

    private var transliteration: some View {
        Form {
            Section {
                LabeledContent("Languages", value: "English ↔ Russian")
            } header: {
                Text("Text conversion")
            } footer: {
                Text("Correct selected text typed with the wrong keyboard layout.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                layoutPicker("English", layouts: LayoutEnumerator.getEnglishLayouts(), first: true)
                layoutPicker("Russian", layouts: LayoutEnumerator.getRussianLayouts(), first: false)
            } header: {
                Text("Keyboard layouts")
            } footer: {
                Text("Used by the Switch Layout shortcut. Text conversion uses the standard English and Russian key mapping.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
    }

    private var translation: some View {
        Form {
            if #available(macOS 15, *) {
                TranslationPreferences(model: model)
            } else {
                Section("Languages") { Text("Requires macOS 15 or later.").foregroundStyle(.secondary) }
            }
        }.formStyle(.grouped)
    }

    private func layoutPicker(_ title: String, layouts: [KeyboardLayout], first: Bool) -> some View {
        Picker(title, selection: Binding<String>(get: {
            (first ? model.settings.selectedLayout1 : model.settings.selectedLayout2)?.sourceID ?? "auto"
        }, set: { id in
            let value = layouts.first { $0.sourceID == id }
            if first { model.settings.selectedLayout1 = value } else { model.settings.selectedLayout2 = value }
            model.changed()
        })) {
            Text("Automatic").tag("auto")
            ForEach(layouts, id: \.sourceID) { Text($0.displayName).tag($0.sourceID) }
        }
    }
}

@available(macOS 15, *)
private struct TranslationPreferences: View {
    @ObservedObject var model: SettingsModel
    @State private var configuration: TranslationSession.Configuration?
    @State private var preparing = false

    var body: some View {
        Section("Languages") {
            Picker("First language", selection: languageBinding(source: true)) {
                languageOptions(selected: model.settings.translationSource)
            }.disabled(preparing)
            Picker("Second language", selection: languageBinding(source: false)) {
                languageOptions(selected: model.settings.translationTarget)
            }.disabled(preparing).help("The shortcut detects which language is selected and translates into the other one.")
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Label(preparing ? "Downloading languages…" : model.downloadAvailability.title,
                          systemImage: preparing ? "arrow.down.circle" : model.downloadAvailability.symbol)
                        .foregroundStyle(model.downloadAvailability == .installed ? Color.green : (model.downloadAvailability == .needsDownload ? Color.orange : Color.secondary))
                    Text(model.pairDescription).font(.caption).foregroundStyle(.secondary)
                }.fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                if preparing { ProgressView().controlSize(.small) }
                if model.downloadAvailability == .needsDownload {
                    Button(preparing ? "Downloading…" : "Download Languages…") {
                        model.downloadIssue = nil
                        preparing = true
                        configuration = .init(source: Locale.Language(identifier: model.sourceForDownload), target: Locale.Language(identifier: model.settings.translationTarget))
                    }.disabled(preparing)
                }
            }
            if let issue = model.downloadIssue {
                Text(issue).font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
            if model.downloadAvailability == .needsDownload || model.downloadIssue != nil {
                HStack(spacing: 4) {
                    Button("Language & Region…") { TranslationLanguages.openSystemSettings() }.buttonStyle(.link)
                    Text("→ Translation Languages → Download").foregroundStyle(.secondary)
                }.font(.caption)
            }
        }
        .task(id: "\(model.settings.translationSource)|\(model.settings.translationTarget)") {
            await model.refreshLanguages()
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                if !Task.isCancelled { await model.refreshLanguages() }
            }
        }
        .translationTask(configuration) { session in
            do {
                // Both languages are explicit; the shortcut chooses the direction from the selection.
                try await session.prepareTranslation()
                await model.refreshLanguages()
            } catch {
                if !Task.isCancelled {
                    model.downloadIssue = "Download could not finish. Check your connection or use Language & Region below."
                }
            }
            preparing = false
            configuration = nil
        }
    }

    @ViewBuilder private func languageOptions(selected: String) -> some View {
        if selected != "auto", !model.languages.contains(selected) { Text(SettingsModel.languageName(selected)).tag(selected) }
        ForEach(model.languages, id: \.self) { id in Text(SettingsModel.languageName(id)).tag(id) }
    }
    private func languageBinding(source: Bool) -> Binding<String> {
        Binding(get: { source ? model.settings.translationSource : model.settings.translationTarget }, set: {
            if source { model.settings.translationSource = $0 } else { model.settings.translationTarget = $0 }
            model.downloadAvailability = .checking; model.downloadIssue = nil
            model.changed()
        })
    }
}

private struct ShortcutRecorder: NSViewRepresentable {
    let config: HotkeyConfig?
    var onChange: (HotkeyConfig) -> Void
    func makeNSView(context: Context) -> ShortcutButton { ShortcutButton() }
    func updateNSView(_ button: ShortcutButton, context: Context) {
        button.config = config
        button.onChange = onChange
        if !button.recording { button.title = config?.displayString ?? "Record Shortcut" }
    }
    static func dismantleNSView(_ button: ShortcutButton, coordinator: ()) { button.cancel() }
}

private final class ShortcutButton: NSButton {
    var config: HotkeyConfig?
    var onChange: ((HotkeyConfig) -> Void)?
    private(set) var recording = false
    private var monitor: Any?
    private var observer: NSObjectProtocol?
    private var lastModifiers: Set<ModifierKey> = []

    init() {
        super.init(frame: .zero)
        bezelStyle = .rounded
        font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        target = self; action = #selector(record)
        setAccessibilityLabel("Record keyboard shortcut")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func record() {
        cancel()
        recording = true; title = "Press keys…"
        observer = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main) { [weak self] _ in self?.cancel() }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self, self.recording else { return event }
            var keys = Set<ModifierKey>()
            if event.modifierFlags.contains(.command) { keys.insert(.command) }
            if event.modifierFlags.contains(.option) { keys.insert(.option) }
            if event.modifierFlags.contains(.control) { keys.insert(.control) }
            if event.modifierFlags.contains(.shift) { keys.insert(.shift) }
            if event.type == .keyDown {
                if event.keyCode == 53 { self.cancel(); return nil }
                guard !keys.isEmpty else { NSSound.beep(); return nil }
                self.finish(.init(modifiers: keys, keyCode: event.keyCode))
            } else if event.keyCode == 57, event.modifierFlags.contains(.capsLock) {
                self.finish(.init(modifiers: keys, keyCode: 57))
            } else if self.lastModifiers.count >= 2, keys.count < self.lastModifiers.count {
                self.finish(.init(modifiers: self.lastModifiers))
            } else { self.lastModifiers = keys }
            return nil
        }
    }
    private func finish(_ value: HotkeyConfig) { cancel(); onChange?(value) }
    func cancel() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let observer { NotificationCenter.default.removeObserver(observer) }
        monitor = nil; observer = nil; recording = false; lastModifiers = []
        title = config?.displayString ?? "Record Shortcut"
    }
}
