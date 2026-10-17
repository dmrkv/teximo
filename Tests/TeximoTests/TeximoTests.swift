import XCTest
import Cocoa
import Translation
@testable import teximo

final class TeximoTests: XCTestCase {
    func testTranslationPreferencesPersistAndResetRestoresClearedShortcuts() {
        let suite = "dev.teximo.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = TeximoSettings(defaults: defaults)
        XCTAssertEqual(settings.translationSource, "en")
        XCTAssertEqual(settings.translationTarget, "de")
        XCTAssertEqual(settings.translationHotkey?.displayString, "⌃⌥T")
        settings.translationSource = "en"
        settings.translationTarget = "fr"
        for action in TeximoAction.allCases { settings.setHotkey(nil, for: action) }
        let reopened = TeximoSettings(defaults: defaults)
        XCTAssertEqual(reopened.translationSource, "en")
        XCTAssertEqual(reopened.translationTarget, "fr")
        for action in TeximoAction.allCases { XCTAssertNil(reopened.hotkey(for: action)) }
        reopened.resetToDefaults()
        for action in TeximoAction.allCases { XCTAssertNotNil(reopened.hotkey(for: action)) }
        XCTAssertEqual(reopened.translationSource, "en")
        XCTAssertEqual(reopened.translationTarget, "de")
    }

    func testKeyShortcutWaitsForReleaseAndDoesNotTriggerFromModifiersAlone() {
        let configs: [(TeximoAction, HotkeyConfig)] = [(.translation, .init(modifiers: [.control, .option], keyCode: 17))]
        var state = ShortcutState()
        XCTAssertNil(state.handle(type: .flagsChanged, flags: [.control, .option], keyCode: 58, configurations: configs))
        XCTAssertNil(state.handle(type: .flagsChanged, flags: [], keyCode: 58, configurations: configs))
        XCTAssertNil(state.handle(type: .keyDown, flags: [.control, .option], keyCode: 17, configurations: configs))
        XCTAssertNil(state.handle(type: .keyDown, flags: [.control, .option], keyCode: 17, isRepeat: true, configurations: configs))
        XCTAssertNil(state.handle(type: .keyUp, flags: [.control, .option], keyCode: 17, configurations: configs))
        XCTAssertEqual(state.handle(type: .flagsChanged, flags: [], keyCode: 59, configurations: configs), .translation)
        XCTAssertNil(state.handle(type: .keyUp, flags: [], keyCode: 17, configurations: configs))
    }

    func testSelectionChordsDoNotFireModifierOnlyActions() {
        let configs: [(TeximoAction, HotkeyConfig)] = [(.caseToggle, .init(modifiers: [.control, .shift]))]
        var state = ShortcutState()
        XCTAssertNil(state.handle(type: .flagsChanged, flags: [.control, .shift], keyCode: 56, configurations: configs))
        XCTAssertNil(state.handle(type: .keyDown, flags: [.control, .shift], keyCode: 124, configurations: configs))
        XCTAssertNil(state.handle(type: .flagsChanged, flags: [], keyCode: 56, configurations: configs))
        XCTAssertNil(state.handle(type: .flagsChanged, flags: [.control, .shift], keyCode: 56, configurations: configs))
        XCTAssertNil(state.handle(type: .flagsChanged, flags: [.control], keyCode: 56, configurations: configs))
        XCTAssertEqual(state.handle(type: .flagsChanged, flags: [], keyCode: 59, configurations: configs), .caseToggle)
    }

    func testLargerModifierChordDoesNotFireShorterChordOnRelease() {
        var state = ShortcutState()
        let configs: [(TeximoAction, HotkeyConfig)] = [(.layout, .init(modifiers: [.command, .shift]))]
        XCTAssertNil(state.handle(type: .flagsChanged, flags: [.command, .shift], keyCode: 56, configurations: configs))
        XCTAssertNil(state.handle(type: .flagsChanged, flags: [.command, .shift, .option], keyCode: 58, configurations: configs))
        XCTAssertNil(state.handle(type: .flagsChanged, flags: [.command, .shift], keyCode: 58, configurations: configs))
        XCTAssertNil(state.handle(type: .flagsChanged, flags: [], keyCode: 56, configurations: configs))
    }

    func testWrongKeyAndDisabledShortcutDoNotFire() {
        var state = ShortcutState()
        let configs: [(TeximoAction, HotkeyConfig)] = [(.translation, .init(modifiers: [.control, .option], keyCode: 17, enabled: false))]
        XCTAssertNil(state.handle(type: .keyDown, flags: [.control, .option], keyCode: 17, configurations: configs))
        XCTAssertNil(state.handle(type: .flagsChanged, flags: [], keyCode: 59, configurations: configs))
        let enabled: [(TeximoAction, HotkeyConfig)] = [(.translation, .init(modifiers: [.control, .option], keyCode: 17))]
        XCTAssertNil(state.handle(type: .keyDown, flags: [.control, .option], keyCode: 7, configurations: enabled))
        XCTAssertNil(state.handle(type: .flagsChanged, flags: [], keyCode: 59, configurations: enabled))
    }

    func testOptionShiftTransliterationRunsOnceInEitherReleaseOrder() {
        let configs: [(TeximoAction, HotkeyConfig)] = [(.transliteration, .init(modifiers: [.option, .shift]))]
        for remaining: NSEvent.ModifierFlags in [.option, .shift] {
            var state = ShortcutState()
            XCTAssertNil(state.handle(type: .flagsChanged, flags: [.option], keyCode: 58, configurations: configs))
            XCTAssertNil(state.handle(type: .flagsChanged, flags: [.option, .shift], keyCode: 56, configurations: configs))
            XCTAssertNil(state.handle(type: .flagsChanged, flags: remaining, keyCode: 56, configurations: configs))
            XCTAssertEqual(state.handle(type: .flagsChanged, flags: [], keyCode: 58, configurations: configs), .transliteration)
            XCTAssertNil(state.handle(type: .flagsChanged, flags: [], keyCode: 58, configurations: configs))
        }
    }

    @MainActor
    func testClipboardOnlyEditorReceivesDelayedCopyAndPasteBeforeRestoration() async {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let custom = NSPasteboard.PasteboardType("dev.teximo.regression-format")
        let item = NSPasteboardItem()
        // Copying identical text must still count as a successful selection read.
        item.setString("ghbdtn", forType: .string)
        item.setData(Data([3, 1, 4]), forType: custom)
        pasteboard.writeObjects([item])
        var insertedText: String?
        let environment = TextActions.Environment(pasteboard: pasteboard, selectedText: { nil }, copy: {
            // Model the keyboard event tap and an app that handle Cmd+C on the main run loop.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                pasteboard.clearContents(); pasteboard.setString("ghbdtn", forType: .string)
            }
        }, paste: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                insertedText = pasteboard.string(forType: .string)
            }
        }, isContextCurrent: { true })
        let result = await TextActions.transformSelection(Transliterator.transliterate, environment: environment)
        XCTAssertEqual(result, .completed)
        XCTAssertEqual(insertedText, "привет")
        XCTAssertEqual(pasteboard.string(forType: .string), "ghbdtn")
        XCTAssertEqual(pasteboard.data(forType: custom), Data([3, 1, 4]))
    }

    @MainActor
    func testTextActionCancelsWhenUserCopiesOrChangesFocusDuringCopy() async {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("original", forType: .string)
        var current = true
        var pasted = false
        let environment = TextActions.Environment(pasteboard: pasteboard, selectedText: { nil }, copy: {
            DispatchQueue.main.async {
                current = false
                pasteboard.clearContents(); pasteboard.setString("new user copy", forType: .string)
            }
        }, paste: { pasted = true }, isContextCurrent: { current })
        let result = await TextActions.transformSelection(Transliterator.transliterate, environment: environment)
        XCTAssertEqual(result, .cancelled)
        XCTAssertFalse(pasted)
        XCTAssertEqual(pasteboard.string(forType: .string), "new user copy")
    }

    @MainActor
    func testMissingCopyDoesNotPasteStaleClipboardText() async {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("old clipboard", forType: .string)
        var pasted = false
        let environment = TextActions.Environment(pasteboard: pasteboard, selectedText: { nil }, copy: {},
                                                  paste: { pasted = true }, isContextCurrent: { true },
                                                  wait: { _ in await Task.yield() })
        let result = await TextActions.transformSelection(Transliterator.transliterate, environment: environment)
        XCTAssertEqual(result, .noSelection)
        XCTAssertFalse(pasted)
        XCTAssertEqual(pasteboard.string(forType: .string), "old clipboard")
    }

    @MainActor
    func testAccessibleSelectionAlsoYieldsBeforeRestoringClipboard() async {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("original", forType: .string)
        var insertedText: String?
        var copyRequested = false
        let environment = TextActions.Environment(pasteboard: pasteboard, selectedText: { "ghbdtn" },
                                                  copy: { copyRequested = true }, paste: {
            DispatchQueue.main.async { insertedText = pasteboard.string(forType: .string) }
        }, isContextCurrent: { true })
        let result = await TextActions.transformSelection(Transliterator.transliterate, environment: environment)
        XCTAssertEqual(result, .completed)
        XCTAssertFalse(copyRequested)
        XCTAssertEqual(insertedText, "привет")
        XCTAssertEqual(pasteboard.string(forType: .string), "original")
    }

    func testDownloadStatusDistinguishesSupportedFromInstalled() {
        if #available(macOS 15, *) {
            XCTAssertEqual(LanguageDownloadAvailability(.supported), .needsDownload)
            XCTAssertEqual(LanguageDownloadAvailability(.installed), .installed)
            XCTAssertEqual(LanguageDownloadAvailability(.unsupported), .unsupported)
        }
    }

    func testAutomaticDetectionResolvesSourceBeforePreparingDownloads() {
        XCTAssertEqual(TranslationLanguages.detectedSource(in: "I would like to have water", supported: ["en", "de", "ru"]), "en")
        XCTAssertEqual(TranslationLanguages.matchingIdentifier("en-GB", supported: ["en", "de"]), "en")
        XCTAssertEqual(TranslationLanguages.suggestedSource(target: "de", supported: ["en", "de"], preferred: ["en-GB"]), "en")
        XCTAssertEqual(TranslationLanguages.suggestedSource(target: "en", supported: ["en", "de"], preferred: ["en-GB"]), "de")
        XCTAssertNil(TranslationLanguages.detectedSource(in: "", supported: ["en", "de"]))
    }

    @MainActor
    func testLegacyAutomaticSourceMigratesToTheDownloadedLanguagePair() {
        let suite = "dev.teximo.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = TeximoSettings(defaults: defaults)
        defaults.set("auto", forKey: "TeximoTranslationSource")
        settings.translationDownloadSource = "ru"
        XCTAssertEqual(TeximoSettings(defaults: defaults).translationDownloadSource, "ru")
        XCTAssertEqual(settings.translationSource, "ru")
        settings.translationSource = "fr"
        XCTAssertEqual(TeximoSettings(defaults: defaults).translationSource, "fr")
        settings.resetToDefaults()
        XCTAssertEqual(settings.translationDownloadSource, "")
        XCTAssertEqual(settings.translationSource, "en")
    }

    func testTranslationDirectionTogglesEnglishAndGerman() {
        XCTAssertEqual(TranslationLanguages.direction(for: "I would like to have water", first: "en", second: "de"),
                       TranslationDirection(source: "en", target: "de"))
        XCTAssertEqual(TranslationLanguages.direction(for: "Ich hätte gerne Wasser", first: "en", second: "de"),
                       TranslationDirection(source: "de", target: "en"))
        XCTAssertEqual(TranslationLanguages.direction(first: "en", second: "de", detected: "de-DE"),
                       TranslationDirection(source: "de", target: "en"))
    }

    func testTranslationDirectionSupportsOtherPairsAndConfiguredOrder() {
        XCTAssertEqual(TranslationLanguages.direction(for: "Я хотел бы выпить воды", first: "ru", second: "de"),
                       TranslationDirection(source: "ru", target: "de"))
        XCTAssertEqual(TranslationLanguages.direction(for: "Ich hätte gerne Wasser", first: "ru", second: "de"),
                       TranslationDirection(source: "de", target: "ru"))
        XCTAssertEqual(TranslationLanguages.direction(first: "de", second: "en", detected: "en-GB"),
                       TranslationDirection(source: "en", target: "de"))
        XCTAssertEqual(TranslationLanguages.direction(first: "en", second: "de", detected: nil),
                       TranslationDirection(source: "en", target: "de"))
    }

    func testAXRangesUseUTF16ForEmojiAndAccents() {
        let text = "Hi 👩🏽‍💻, café!"
        let range = (text as NSString).range(of: "👩🏽‍💻, café")
        XCTAssertEqual(EditableSelection.substring(text, range: CFRange(location: range.location, length: range.length)), "👩🏽‍💻, café")
        XCTAssertNil(EditableSelection.substring(text, range: CFRange(location: -1, length: 3)))
        XCTAssertNil(EditableSelection.substring(text, range: CFRange(location: 0, length: Int.max)))
    }

    @MainActor
    func testPasteboardRestoresAllFormatsAndPreservesNewUserCopy() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let custom = NSPasteboard.PasteboardType("dev.teximo.test-format")
        let item = NSPasteboardItem()
        item.setString("original", forType: .string)
        item.setData(Data([0, 1, 255]), forType: custom)
        pasteboard.writeObjects([item])
        let snapshot = PasteboardSnapshot(pasteboard)
        pasteboard.clearContents(); pasteboard.setString("translation", forType: .string)
        snapshot.restore(to: pasteboard, ifUnchanged: pasteboard.changeCount)
        XCTAssertEqual(pasteboard.string(forType: .string), "original")
        XCTAssertEqual(pasteboard.data(forType: custom), Data([0, 1, 255]))
        pasteboard.clearContents(); pasteboard.setString("translation", forType: .string)
        let change = pasteboard.changeCount
        pasteboard.clearContents(); pasteboard.setString("new user copy", forType: .string)
        snapshot.restore(to: pasteboard, ifUnchanged: change)
        XCTAssertEqual(pasteboard.string(forType: .string), "new user copy")
    }
}
