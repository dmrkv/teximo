# Teximo v1.6.0 - Rectangle-Style Settings UI

Major Settings UI redesign with intuitive feature management and menu bar customization!

## 🎨 What's New

### Rectangle-Style Settings Interface
- **X-buttons to clear shortcuts** - Click × next to any shortcut to disable that feature instantly
- **No checkboxes** - Clean, minimal interface inspired by Rectangle app
- **Smart visibility** - X-buttons auto-hide when shortcut is empty
- **Clear placeholder** - Shows "Record Shortcut" when feature is disabled

### Menu Bar Icon Hiding
- **Hide icon option** - New "Show icon in menu bar" checkbox in Settings
- **Auto-open Settings** - When icon is hidden, Settings automatically opens on app launch
- **Works on reopen** - Run `open Teximo.app` or use Spotlight while running to access Settings
- **Seamless UX** - No way to get locked out of Settings

### UI Polish
- Window title now shows "Teximo Settings" (was "Settings")
- Removed static instruction text for cleaner look
- Instructions only appear during shortcut recording

## 🔧 How It Works

**Disable a feature**: Click the × button next to its shortcut → Shortcut cleared → Feature disabled

**Enable a feature**: Click "Record Shortcut" → Press your desired key combination → Feature enabled

**Features controlled by shortcuts**:
- Empty/cleared shortcut = Feature disabled
- Set shortcut = Feature enabled  
- Menu displays "Disabled" for cleared features

## 📦 Installation

### Direct Download
1. Download `Teximo-1.6.0.dmg`
2. Open DMG and drag Teximo to Applications
3. Launch Teximo from Applications

### Homebrew
```bash
brew install dmrkv/teximo/teximo
```

## 🔐 Verification

SHA256: `0e1568b798b74fb35274a50dd3f20bc75550a66f9b480103725715eb3ff2e6db`

## 🐛 Bug Fixes & Improvements
- Fixed Settings window activation when menu bar icon is hidden
- Improved accessibility permission flow
- Better window management for accessory apps

## 📝 Technical Details
- macOS 13.0+ (Ventura or later)
- Universal Binary (Intel/Apple Silicon)
- Size: 2.9 MB

---

**Full Changelog**: https://github.com/dmrkv/teximo/compare/v1.5.0...v1.6.0
