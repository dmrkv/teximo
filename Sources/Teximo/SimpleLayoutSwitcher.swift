import Cocoa
import Carbon

final class SimpleLayoutSwitcher {
    static func switchLayout() {
        print("[Teximo] SimpleLayoutSwitcher: Switching layout programmatically")
        
        // Get all enabled input sources
        guard let inputSources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            print("[Teximo] Failed to get input sources list")
            return
        }
        
        // Get current input source
        guard let currentSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            print("[Teximo] Failed to get current input source")
            return
        }
        
        // Get current source ID
        let currentID = TISGetInputSourceProperty(currentSource, kTISPropertyInputSourceID)
        let currentIDString = (currentID as! CFString) as String
        print("[Teximo] Current input source: \(currentIDString)")
        
        // Filter to only keyboard input sources that are enabled
        let enabledSources = inputSources.filter { source in
            // Check if selectable
            guard let selectable = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsSelectCapable) else {
                return false
            }
            let selectableBool = Unmanaged<CFBoolean>.fromOpaque(selectable).takeUnretainedValue()
            let isSelectable = CFBooleanGetValue(selectableBool)
            
            // Check if enabled
            guard let enabled = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsEnabled) else {
                return false
            }
            let enabledBool = Unmanaged<CFBoolean>.fromOpaque(enabled).takeUnretainedValue()
            let isEnabled = CFBooleanGetValue(enabledBool)
            
            return isSelectable && isEnabled
        }
        
        print("[Teximo] Found \(enabledSources.count) enabled input sources")
        
        // Find current index
        guard let currentIndex = enabledSources.firstIndex(where: { source in
            guard let id = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return false }
            let idString = (id as! CFString) as String
            return idString == currentIDString
        }) else {
            print("[Teximo] Current source not found in enabled sources")
            return
        }
        
        // Get next source (cycle back to 0 if at end)
        let nextIndex = (currentIndex + 1) % enabledSources.count
        let nextSource = enabledSources[nextIndex]
        
        // Get next source ID for logging
        if let nextID = TISGetInputSourceProperty(nextSource, kTISPropertyInputSourceID) {
            let nextIDString = (nextID as! CFString) as String
            print("[Teximo] Switching to: \(nextIDString)")
        }
        
        // Switch to the next source - THIS IS INSTANT AND SILENT!
        let result = TISSelectInputSource(nextSource)
        if result == noErr {
            print("[Teximo] Layout switched successfully")
        } else {
            print("[Teximo] Failed to switch layout, error code: \(result)")
        }
    }
}

