import Cocoa
import Carbon

struct KeyboardLayout: Codable, Equatable, Hashable {
    let sourceID: String
    let displayName: String
    let languages: [String]  // e.g., ["en"], ["ru"]
    
    var primaryLanguage: String? {
        languages.first
    }
    
    var isEnglish: Bool {
        languages.contains(where: { $0.lowercased().hasPrefix("en") })
    }
    
    var isRussian: Bool {
        languages.contains(where: { $0.lowercased().hasPrefix("ru") })
    }
}

@MainActor
class LayoutEnumerator {
    static func getAllKeyboardLayouts() -> [KeyboardLayout] {
        guard let sources = enabledKeyboardSources() else { return [] }
        
        return sources.compactMap { source in
            guard let sourceID = stringProp(source, kTISPropertyInputSourceID),
                  let displayName = stringProp(source, kTISPropertyLocalizedName) else {
                return nil
            }
            
            let languages = getLanguages(for: source)
            
            return KeyboardLayout(
                sourceID: sourceID,
                displayName: displayName,
                languages: languages
            )
        }
    }
    
    static func getEnglishLayouts() -> [KeyboardLayout] {
        getAllKeyboardLayouts().filter { $0.isEnglish }
    }
    
    static func getRussianLayouts() -> [KeyboardLayout] {
        getAllKeyboardLayouts().filter { $0.isRussian }
    }
    
    // MARK: - Private Helpers
    
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
            return CFBooleanGetValue(unsafeDowncast(cf, to: CFBoolean.self))
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
    
    private static func getLanguages(for source: TISInputSource) -> [String] {
        guard let cf = prop(source, kTISPropertyInputSourceLanguages) else { return [] }
        guard CFGetTypeID(cf) == CFArrayGetTypeID() else { return [] }
        let arrayRef = unsafeDowncast(cf, to: CFArray.self)
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
