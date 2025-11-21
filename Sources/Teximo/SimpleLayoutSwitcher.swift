import Cocoa
import Carbon

@MainActor
final class SimpleLayoutSwitcher {
    private static var lastRequestedLanguage: String?

    static func switchLayout() {
        // Make sure we always touch UI APIs on the main thread
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                switchLayout()
            }
            return
        }

        print("[Teximo] SimpleLayoutSwitcher: Switching layout programmatically (TIS)")
        
        // Check if user has selected specific layouts
        let settings = TeximoSettings.shared
        if let layout1 = settings.selectedLayout1, let layout2 = settings.selectedLayout2 {
            // Use selected layout pair
            print("[Teximo] Using selected layout pair")
            switchBetweenLayouts(layout1, layout2)
            return
        }

        // Otherwise, use auto-detect (existing EN/RU switching logic)
        print("[Teximo] Using auto-detect EN/RU switching")
        guard let enabledSources = enabledKeyboardSources() else {
            print("[Teximo] SimpleLayoutSwitcher: Unable to enumerate enabled keyboard sources")
            return
        }

        guard let currentSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            print("[Teximo] SimpleLayoutSwitcher: Failed to get current input source")
            return
        }

        let currentID = stringProp(currentSource, kTISPropertyInputSourceID) ?? "<unknown>"
        print("[Teximo] SimpleLayoutSwitcher: Current input source = \(currentID)")

        let currentLanguages = languages(for: currentSource)
        let targetLanguage = determineTargetLanguage(fromCurrentLanguages: currentLanguages)
        print("[Teximo] SimpleLayoutSwitcher: Target language = \(targetLanguage ?? "nil")")

        if let language = targetLanguage,
           let targetSource = firstSource(for: language, in: enabledSources),
           select(source: targetSource, expectation: language) {
            lastRequestedLanguage = language
            return
        }

        // Either no RU/EN layouts were found, or selection failed – fall back to cycling.
        print("[Teximo] SimpleLayoutSwitcher: Falling back to next available input source")
        cycleToNextSource(from: currentSource, enabledSources: enabledSources)
    }
    
    // Switch between two specific layouts
    private static func switchBetweenLayouts(_ layout1: KeyboardLayout, _ layout2: KeyboardLayout) {
        guard let enabledSources = enabledKeyboardSources() else {
            print("[Teximo] Unable to get enabled sources")
            return
        }
        
        guard let currentSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            print("[Teximo] Failed to get current source")
            return
        }
        
        let currentID = stringProp(currentSource, kTISPropertyInputSourceID) ?? ""
        print("[Teximo] Current: \(currentID)")
        
        // Determine which layout to switch to
        let targetLayout = (currentID == layout1.sourceID) ? layout2 : layout1
        print("[Teximo] Target: \(targetLayout.displayName)")
        
        // Find the target source
        guard let targetSource = enabledSources.first(where: { source in
            stringProp(source, kTISPropertyInputSourceID) == targetLayout.sourceID
        }) else {
            print("[Teximo] Target layout not found in enabled sources")
            return
        }
        
        // Select it
        let result = TISSelectInputSource(targetSource)
        if result == noErr {
            print("[Teximo] ✅ Switched to: \(targetLayout.displayName)")
        } else {
            print("[Teximo] ❌ Failed to switch: error \(result)")
        }
    }

    private static func determineTargetLanguage(fromCurrentLanguages languages: [String]) -> String? {
        let normalizedLanguages = languages.map { $0.lowercased() }
        if normalizedLanguages.contains(where: { $0.hasPrefix("ru") }) {
            return "en"
        }
        if normalizedLanguages.contains(where: { $0.hasPrefix("en") }) {
            return "ru"
        }
        // If current layout is neither EN nor RU, alternate based on our last request so the toggle remains predictable.
        if lastRequestedLanguage?.hasPrefix("ru") == true {
            return "en"
        }
        return "ru"
    }

    private static func cycleToNextSource(from currentSource: TISInputSource, enabledSources: [TISInputSource]) {
        guard let currentID = stringProp(currentSource, kTISPropertyInputSourceID) else {
            print("[Teximo] SimpleLayoutSwitcher: Unable to determine current source ID for fallback")
            return
        }

        guard let currentIndex = enabledSources.firstIndex(where: {
            stringProp($0, kTISPropertyInputSourceID) == currentID
        }) else {
            print("[Teximo] SimpleLayoutSwitcher: Current source not found in enabled list")
            return
        }

        let nextIndex = (currentIndex + 1) % enabledSources.count
        let nextSource = enabledSources[nextIndex]
        _ = select(source: nextSource, expectation: nil)
    }

    @discardableResult
    private static func select(source: TISInputSource, expectation: String?) -> Bool {
        let targetID = stringProp(source, kTISPropertyInputSourceID) ?? "<unknown>"
        print("[Teximo] SimpleLayoutSwitcher: Selecting input source \(targetID)")
        let result = TISSelectInputSource(source)
        guard result == noErr else {
            print("[Teximo] SimpleLayoutSwitcher: TISSelectInputSource failed with code \(result)")
            return false
        }

        // Verify the switch to ensure we actually landed on the desired layout.
        usleep(30_000)
        if let verifySource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
           let verifyID = stringProp(verifySource, kTISPropertyInputSourceID),
           verifyID == targetID {
            print("[Teximo] SimpleLayoutSwitcher: Verified switch to \(targetID)")
            if let expectation = expectation {
                print("[Teximo] SimpleLayoutSwitcher: Active layout now serves \(expectation.uppercased())")
            }
            return true
        }

        print("[Teximo] SimpleLayoutSwitcher: Verification failed – expected \(targetID)")
        return false
    }

    private static func firstSource(for language: String, in sources: [TISInputSource]) -> TISInputSource? {
        let normalizedLanguage = language.lowercased()
        return sources.first(where: { source in
            languages(for: source).contains { $0.lowercased().hasPrefix(normalizedLanguage) }
        })
    }

    private static func enabledKeyboardSources() -> [TISInputSource]? {
        guard let listRef = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            return nil
        }

        let enabledSources: [TISInputSource] = listRef.filter { source in
            let isKeyboard = (stringProp(source, kTISPropertyInputSourceCategory) == (kTISCategoryKeyboardInputSource as String))
            let isSelectable = boolProp(source, kTISPropertyInputSourceIsSelectCapable)
            let isEnabled = boolProp(source, kTISPropertyInputSourceIsEnabled)
            return isKeyboard && isSelectable && isEnabled
        }

        return enabledSources.isEmpty ? nil : enabledSources
    }

    private static func boolProp(_ source: TISInputSource, _ key: CFString) -> Bool {
        guard let cf = prop(source, key) else { return false }
        if CFGetTypeID(cf) == CFBooleanGetTypeID() {
            return CFBooleanGetValue(unsafeBitCast(cf, to: CFBoolean.self))
        }
        return false
    }

    private static func stringProp(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let cf = prop(source, key) else { return nil }
        if CFGetTypeID(cf) == CFStringGetTypeID() {
            return (cf as! String)
        }
        return nil
    }

    private static func languages(for source: TISInputSource) -> [String] {
        guard let cf = prop(source, kTISPropertyInputSourceLanguages) else { return [] }
        guard CFGetTypeID(cf) == CFArrayGetTypeID() else { return [] }
        let arrayRef = unsafeBitCast(cf, to: CFArray.self)
        let count = CFArrayGetCount(arrayRef)
        var values: [String] = []
        values.reserveCapacity(count)
        for index in 0..<count {
            let rawValue = CFArrayGetValueAtIndex(arrayRef, index)
            let cfString = unsafeBitCast(rawValue, to: CFString.self)
            values.append(cfString as String)
        }
        return values
    }

    @inline(__always)
    private static func prop(_ source: TISInputSource, _ key: CFString) -> CFTypeRef? {
        guard let raw = TISGetInputSourceProperty(source, key) else { return nil }
        return unsafeBitCast(raw, to: CFTypeRef.self)
    }
}
