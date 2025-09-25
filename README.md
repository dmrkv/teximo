# Teximo

A beautiful macOS menu bar app for keyboard layout switching and text manipulation.

## Features

- **⌘+Shift**: Switch keyboard layouts instantly
- **⌥+Shift**: Transliterate text between English and Russian (Cyrillic)
- **Smart Detection**: Automatically detects text direction for transliteration
- **Beautiful UI**: Clean, modern interface with guided setup

## Installation

### Option 1: Homebrew (Recommended)
```bash
brew install dmrkv/teximo/teximo
```

> **Note**: This installs Teximo from the Homebrew tap. Make sure you have Homebrew installed first.

### Option 2: Download from Releases
1. Go to the [Releases](https://github.com/dmrkv/teximo/releases) page
2. Download the latest `Teximo.dmg` file
3. Open the DMG and drag Teximo to your Applications folder
4. **🚨 IMPORTANT - Security Warning Fix:**
   
   When you first try to launch Teximo, macOS will show a security warning:
   > "Teximo" cannot be opened because the developer cannot be verified.
   
   **To fix this, you MUST:**
   - **Right-click** on Teximo.app in Applications folder
   - Select **"Open"** from the context menu
   - Click **"Open"** in the security dialog
   
   This is a one-time step - after this, Teximo will launch normally!
5. Launch Teximo from Applications

### Option 3: Build from Source
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

## Troubleshooting

### Security Warning Issues
If you see "Teximo cannot be opened because the developer cannot be verified":
1. **Right-click** on Teximo.app in Applications folder
2. Select **"Open"** from the context menu
3. Click **"Open"** in the security dialog

### Alternative Method (if right-click doesn't work):
1. Go to **System Preferences** → **Security & Privacy** → **General**
2. Look for a message about Teximo being blocked
3. Click **"Open Anyway"**

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
