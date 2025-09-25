# Teximo Release Guide

This guide explains how to release new versions of Teximo with both DMG and Homebrew distribution.

## Quick Release

For a new version (e.g., 1.1.0):

```bash
./update_both.sh 1.1.0
```

This script will:
1. Build the app
2. Create DMG
3. Update SHA256
4. Update both repositories
5. Push everything

## Manual Steps After Running Script

1. **Go to GitHub Releases**: https://github.com/dmrkv/teximo/releases
2. **Click "Edit"** on the latest release
3. **Upload new DMG**: `build/Teximo-1.1.0.dmg`
4. **Update release title**: `Teximo v1.1.0`
5. **Click "Update release"**

## What Gets Updated Automatically

- ✅ Homebrew formula version
- ✅ SHA256 hash
- ✅ DMG filename
- ✅ Both GitHub repositories
- ✅ Git commits and pushes

## What You Need to Do Manually

- 📤 Upload DMG to GitHub release
- 📝 Update release title and description

## Testing the Release

### Test Homebrew Installation
```bash
brew install dmrkv/teximo/teximo
```

### Test DMG Installation
1. Download DMG from GitHub releases
2. Install and test the app

## File Locations

- **DMG**: `build/Teximo-{VERSION}.dmg`
- **Homebrew Formula**: `Formula/teximo.rb`
- **Homebrew Tap**: `/Users/dima/Dev/homebrew-teximo/`

## Troubleshooting

### If Homebrew Installation Fails
- Check that `homebrew-teximo` repository exists
- Verify SHA256 hash is correct
- Ensure DMG is uploaded to GitHub releases

### If DMG Installation Fails
- Check that DMG is properly signed
- Verify security warning bypass instructions
- Test on different macOS versions
