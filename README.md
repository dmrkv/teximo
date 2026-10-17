# Teximo

A seamless macOS menu bar app for keyboard layout switching and text manipulation.

## Features

- **⚙️ Customizable Shortcuts**: Configure your own keyboard shortcuts for all actions
- **🌍 Native Translation**: Translate selected text in editable fields with Apple Translation (macOS 15+)
- **🎨 Settings Window**: Translucent sidebar with dedicated General, Transliteration, Translation, and Shortcuts pages
- **⌨️ Smart Layout Switching**: Choose specific keyboard layouts for English and Russian
- **🔄 Text Transliteration**: Convert selected text between English and Russian (Cyrillic)
- **🔠 Case Toggle**: Cycle through lowercase, UPPERCASE, Title Case, and Sentence case
- **🔍 Smart Detection**: Automatically detects text direction for transliteration
- **👻 Invisible Operation**: Works seamlessly in the background without interrupting your workflow
- **⚠️ Conflict Detection**: Visual warnings when shortcuts overlap

## Installation

### Option 1: Homebrew (Recommended)
```bash
brew install dmrkv/teximo/teximo
```

Quit any older Teximo copy, then launch the Homebrew-managed app:

```bash
open "$(brew --prefix teximo)/Teximo.app"
```

For an existing Homebrew installation, use `brew update` followed by `brew upgrade dmrkv/teximo/teximo`. If your previous copy came from a DMG or a development build, run `brew install` first; Homebrew cannot upgrade a copy it does not manage.

If Homebrew reports an untrusted formula, run `brew trust --formula dmrkv/teximo/teximo` once, then retry. A fully qualified `brew install dmrkv/teximo/teximo` grants trust to that formula on Homebrew versions that require it.

### Option 2: Download from Releases
1. Go to the [Releases](https://github.com/dmrkv/teximo/releases) page
2. Download the latest `Teximo-x.x.x.dmg` file
3. Open the DMG and drag Teximo to your Applications folder
4. Launch Teximo from Applications and grant Accessibility access when prompted.

### Option 3: Build from Source
1. Clone this repository
2. Open `Teximo.xcodeproj` in Xcode
3. Build and run (Cmd+R)

## First Launch

When you first launch Teximo, you'll see a permission window guiding you through enabling accessibility permissions:

1. Click "Open System Settings"
2. Navigate to Privacy & Security → Accessibility
4. Find 'Teximo' in the list and check the box

## Usage

Once permissions are granted, Teximo will appear in your menu bar with a "T" icon.

### Settings Window

Click the menu bar icon and select **"Settings..."**. The translucent sidebar has **General**, **Transliteration**, **Translation**, and **Shortcuts** pages. Use them to:
- Choose the two languages to translate between
- Customize keyboard shortcuts for layout switching, transliteration, case toggle, and translation
- Choose specific keyboard layouts for English and Russian
- Enable/disable launching Teximo at macOS startup
- Reset all settings to defaults

### Default Shortcuts

The app works globally in any application with these default shortcuts (customizable in Settings):

- **⌘⇧** (Cmd+Shift): Switch between keyboard layouts
- **⌥⇧** (Option+Shift): Transliterate selected text between English and Russian
- **⌃⇧** (Ctrl+Shift): Toggle case of selected text
- **⌃⌥T** (Ctrl+Option+T): Translate selected text into the other language of your pair

Release the keys to run an action. Modifier-only shortcuts do not run when used with other keys, such as when selecting text.

### Translate a Selection

1. Open **Settings → Translation**. Choose **First language** and **Second language**. The default pair is English ↔ German.
2. Select text in an editable field in another app.
3. Press **Control–Option–T** and release the keys. Teximo detects which language is selected and translates into the other one. English becomes German; select the German text and press the same shortcut to translate back to English.

Translation runs on your Mac using Apple's Translation framework. Normal translation and transliteration replace the selection silently, without a progress window or focus change. If language files are missing, the translation panel offers **Download Languages…** and macOS settings instructions. Downloading needs an internet connection. After downloading, select the text again and use the shortcut. Settings shows **Language download needed** or **Language files downloaded** for the selected pair. Click **Download Languages…** to ask macOS to install missing files. If the native download cannot start, **Open Language & Region…** takes you to macOS settings; open **Translation Languages** there and download both languages. Supported languages come from the system rather than a fixed list.

If you type, change the selection, or switch fields during translation, Teximo leaves the field alone and offers **Copy Translation**. Translation preserves all clipboard formats and avoids overwriting a new clipboard item copied while pasting.

Accessibility access is required. Password fields, read-only content, and apps that do not expose selected text through Accessibility are not supported. Translation requires **macOS 15 or later**; the existing layout, transliteration, and case tools continue to support macOS 13–14.

### Development Checks

With a configured Xcode toolchain and its license accepted:

```bash
swift test
xcodebuild -project Teximo.xcodeproj -scheme Teximo -configuration Debug -derivedDataPath /tmp/teximo-build CODE_SIGNING_ALLOWED=NO build
```

Tests cover shortcut release behavior, selection chords, disabled shortcuts, language persistence/reset, UTF-16 selection ranges, clipboard restoration, and delayed copy/paste delivery in editors that do not expose Accessibility selections. Before publishing, also test translation in TextEdit and a browser input, download status, consent/cancellation, and changing the selection while translation is running.

The DMG, Developer ID signing/notarization, and Homebrew tap distribution remain in place. See [RELEASE_GUIDE.md](RELEASE_GUIDE.md) before publishing a new version; update the tap URL and checksum only after creating the signed release artifact.

## Troubleshooting

### "Damaged and can't be opened" Error
See the **Security Setup** section under Option 2 installation above.

### Layout Switching Popover (macOS Sonoma and later)
If you see a small popover appearing near your cursor when switching layouts, this is a macOS system feature introduced in Sonoma. Teximo uses direct system APIs that work instantly and don't depend on macOS keyboard shortcuts.

To disable the system popover (optional):
```bash
defaults write kCFPreferencesAnyApplication TSMLanguageIndicatorEnabled 0
```
After running this command, restart your applications for the change to take effect. This will revert to the older style indicator or hide it completely.

### Other Issues
If you encounter any other issues, please check the [Issues](https://github.com/dmrkv/teximo/issues) page or create a new issue.

## Requirements

- macOS 13.0 or later
- Accessibility permissions (guided setup on first launch)

## Privacy

Teximo processes text locally on your device. No data is sent to external servers. The app only requires accessibility permissions to simulate keystrokes for text manipulation.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Acknowledgments

Inspired by the need for efficient keyboard layout switching and text manipulation on macOS.

<!-- Updated Fri Sep 26 18:52:10 CEST 2025 -->
