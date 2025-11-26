import Foundation
import Cocoa

// Represents a modifier key combination for a hotkey
struct HotkeyConfig: Codable, Equatable {
    var modifiers: Set<ModifierKey>
    var keyCode: UInt16? // Optional key code for combinations like Ctrl+Space
    var enabled: Bool
    
    init(modifiers: Set<ModifierKey>, keyCode: UInt16? = nil, enabled: Bool = true) {
        self.modifiers = modifiers
        self.keyCode = keyCode
        self.enabled = enabled
    }
    
    // Check if NSEvent.ModifierFlags matches this config
    func matches(_ flags: NSEvent.ModifierFlags) -> Bool {
        guard enabled else { return false }
        
        let hasCommand = flags.contains(.command)
        let hasShift = flags.contains(.shift)
        let hasOption = flags.contains(.option)
        let hasControl = flags.contains(.control)
        
        let wantCommand = modifiers.contains(.command)
        let wantShift = modifiers.contains(.shift)
        let wantOption = modifiers.contains(.option)
        let wantControl = modifiers.contains(.control)
        
        return hasCommand == wantCommand &&
               hasShift == wantShift &&
               hasOption == wantOption &&
               hasControl == wantControl
    }
    
    var displayString: String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        
        if let code = keyCode {
            parts.append(keyCodeToString(code))
        }
        
        return parts.isEmpty ? "None" : parts.joined()
    }
    
    private func keyCodeToString(_ code: UInt16) -> String {
        switch code {
        // Letters
        case 0: return "A"
        case 11: return "B"
        case 8: return "C"
        case 2: return "D"
        case 14: return "E"
        case 3: return "F"
        case 5: return "G"
        case 4: return "H"
        case 34: return "I"
        case 38: return "J"
        case 40: return "K"
        case 37: return "L"
        case 46: return "M"
        case 45: return "N"
        case 31: return "O"
        case 35: return "P"
        case 12: return "Q"
        case 15: return "R"
        case 1: return "S"
        case 17: return "T"
        case 32: return "U"
        case 9: return "V"
        case 13: return "W"
        case 7: return "X"
        case 16: return "Y"
        case 6: return "Z"
        
        // Numbers
        case 29: return "0"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 23: return "5"
        case 22: return "6"
        case 26: return "7"
        case 28: return "8"
        case 25: return "9"
        
        // Special keys
        case 49: return "Space"
        case 57: return "⇪" // CapsLock
        case 36: return "↩" // Return
        case 48: return "⇥" // Tab
        case 51: return "⌫" // Delete
        case 53: return "⎋" // Escape
        case 50: return "`"
        case 27: return "-"
        case 24: return "="
        case 33: return "["
        case 30: return "]"
        case 42: return "\\"
        case 41: return ";"
        case 39: return "'"
        case 43: return ","
        case 47: return "."
        case 44: return "/"
        
        default: return String(format: "Key%d", code)
        }
    }
}

enum ModifierKey: String, Codable, CaseIterable {
    case command
    case shift
    case option
    case control
}

// Settings manager using UserDefaults
class TeximoSettings {
    static let shared = TeximoSettings()
    
    private let defaults = UserDefaults.standard
    
    // Keys for UserDefaults
    private let layoutSwitchKey = "TeximoLayoutSwitchHotkey"
    private let transliterationKey = "TeximoTransliterationHotkey"
    private let caseToggleKey = "TeximoCaseToggleHotkey"
    private let selectedLayout1Key = "TeximoSelectedLayout1"
    private let selectedLayout2Key = "TeximoSelectedLayout2"
    
    // Default configurations (matching Punto Switcher)
    private let defaultLayoutSwitch = HotkeyConfig(modifiers: [.command, .shift])
    private let defaultTransliteration = HotkeyConfig(modifiers: [.option, .shift])
    private let defaultCaseToggle = HotkeyConfig(modifiers: [.control, .shift])
    
    // Hotkey configurations (optional - nil means disabled/cleared)
    var layoutSwitchHotkey: HotkeyConfig? {
        get {
            if let data = defaults.data(forKey: layoutSwitchKey) {
                return try? JSONDecoder().decode(HotkeyConfig.self, from: data)
            }
            // Return default on first use (when key doesn't exist at all)
            if !defaults.bool(forKey: "hasSetLayoutSwitchHotkey") {
                return defaultLayoutSwitch
            }
            return nil // Explicitly cleared
        }
        set {
            defaults.set(true, forKey: "hasSetLayoutSwitchHotkey")
            if let config = newValue, let data = try? JSONEncoder().encode(config) {
                defaults.set(data, forKey: layoutSwitchKey)
            } else {
                defaults.removeObject(forKey: layoutSwitchKey)
            }
        }
    }
    
    var transliterationHotkey: HotkeyConfig? {
        get {
            if let data = defaults.data(forKey: transliterationKey) {
                return try? JSONDecoder().decode(HotkeyConfig.self, from: data)
            }
            if !defaults.bool(forKey: "hasSetTransliterationHotkey") {
                return defaultTransliteration
            }
            return nil
        }
        set {
            defaults.set(true, forKey: "hasSetTransliterationHotkey")
            if let config = newValue, let data = try? JSONEncoder().encode(config) {
                defaults.set(data, forKey: transliterationKey)
            } else {
                defaults.removeObject(forKey: transliterationKey)
            }
        }
    }
    
    var caseToggleHotkey: HotkeyConfig? {
        get {
            if let data = defaults.data(forKey: caseToggleKey) {
                return try? JSONDecoder().decode(HotkeyConfig.self, from: data)
            }
            if !defaults.bool(forKey: "hasSetCaseToggleHotkey") {
                return defaultCaseToggle
            }
            return nil
        }
        set {
            defaults.set(true, forKey: "hasSetCaseToggleHotkey")
            if let config = newValue, let data = try? JSONEncoder().encode(config) {
                defaults.set(data, forKey: caseToggleKey)
            } else {
                defaults.removeObject(forKey: caseToggleKey)
            }
        }
    }
    
    // Selected keyboard layouts
    var selectedLayout1: KeyboardLayout? {
        get {
            if let data = defaults.data(forKey: selectedLayout1Key),
               let layout = try? JSONDecoder().decode(KeyboardLayout.self, from: data) {
                return layout
            }
            return nil
        }
        set {
            if let layout = newValue, let data = try? JSONEncoder().encode(layout) {
                defaults.set(data, forKey: selectedLayout1Key)
            } else {
                defaults.removeObject(forKey: selectedLayout1Key)
            }
        }
    }
    
    var selectedLayout2: KeyboardLayout? {
        get {
            if let data = defaults.data(forKey: selectedLayout2Key),
               let layout = try? JSONDecoder().decode(KeyboardLayout.self, from: data) {
                return layout
            }
            return nil
        }
        set {
            if let layout = newValue, let data = try? JSONEncoder().encode(layout) {
                defaults.set(data, forKey: selectedLayout2Key)
            } else {
                defaults.removeObject(forKey: selectedLayout2Key)
            }
        }
    }
    
    // Menu bar icon visibility
    private let showMenuBarIconKey = "TeximoShowMenuBarIcon"
    private let hasSetShowMenuBarIconKey = "TeximoHasSetShowMenuBarIcon"
    var showMenuBarIcon: Bool {
        get {
            if !defaults.bool(forKey: hasSetShowMenuBarIconKey) {
                return true // Default to visible
            }
            return defaults.bool(forKey: showMenuBarIconKey)
        }
        set {
            defaults.set(newValue, forKey: showMenuBarIconKey)
            defaults.set(true, forKey: hasSetShowMenuBarIconKey)
        }
    }
    
    // Reset to defaults
    func resetToDefaults() {
        defaults.removeObject(forKey: layoutSwitchKey)
        defaults.removeObject(forKey: transliterationKey)
        defaults.removeObject(forKey: caseToggleKey)
        defaults.removeObject(forKey: selectedLayout1Key)
        defaults.removeObject(forKey: selectedLayout2Key)
    }
}
