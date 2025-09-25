# Teximo

A beautiful macOS menu bar app for keyboard layout switching and text manipulation.

## Features

- **⌘+Shift**: Switch keyboard layouts instantly
- **⌥+Shift**: Transliterate text between English and Russian (Cyrillic)
- **Ctrl+Shift**: Toggle text case (lowercase → Title Case → UPPERCASE)
- **Smart Detection**: Automatically detects text direction for transliteration
- **Beautiful UI**: Clean, modern interface with guided setup

## Installation

### Option 1: Download from Releases
1. Go to the [Releases](https://github.com/yourusername/teximo/releases) page
2. Download the latest `Teximo.dmg` file
3. Open the DMG and drag Teximo to your Applications folder
4. Launch Teximo from Applications

### Option 2: Build from Source
1. Clone this repository
2. Open `Teximo.xcodeproj` in Xcode
3. Build and run (Cmd+R)

## First Launch

When you first launch Teximo, you'll see a beautiful permission window guiding you through enabling accessibility permissions:

1. Click "Open System Settings"
2. Navigate to Privacy & Security → Accessibility
3. Click the lock icon and enter your password
4. Find 'Teximo' in the list and check the box
5. Return to Teximo and click "Check Again"

## Usage

Once permissions are granted, Teximo will appear in your menu bar with a "T" icon. The app works globally in any application:

- **⌘+Shift**: Switch between keyboard layouts
- **⌥+Shift**: Select text and press this combination to transliterate between English and Russian
- **Ctrl+Shift**: Select text and press this combination to cycle through text cases

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