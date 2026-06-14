# Teximo Release Guide

This guide explains how to release new versions of Teximo with both DMG and Homebrew distribution.

## Prerequisites

### Required for Distribution

To distribute Teximo without "damaged and can't be opened" errors, you need:

1. **Apple Developer Program Membership** ($99/year)
   - Enroll at: https://developer.apple.com/programs/enroll/

2. **Developer ID Application Certificate**
   - Open Xcode → Settings → Accounts
   - Select your Apple ID → Manage Certificates
   - Click '+' → **Developer ID Application** (NOT "Apple Development")

3. **App-Specific Password** for notarization
   - Go to: https://appleid.apple.com/account/manage
   - Security → App-Specific Passwords → Generate
   - Name it "Teximo Notarization" and save the password

4. **Team ID**
   - Found at: https://developer.apple.com/account → Membership

### Set Up Notarization Credentials (Required for Release)

**If an app-specific password was ever committed to git, revoke it at [appleid.apple.com](https://appleid.apple.com) → Sign-In and Security → App-Specific Passwords, then create a new one.**

1. Copy the example env file (never commit `.env`):

   ```bash
   cp .env.example .env
   ```

2. Edit `.env` with your Apple ID, Team ID (`JCQ85NRZVZ` from [Membership](https://developer.apple.com/account)), and a **new** app-specific password.

3. Store credentials in the macOS Keychain (recommended):

   ```bash
   chmod +x scripts/setup_notary_keychain.sh
   ./scripts/setup_notary_keychain.sh
   ```

4. In `.env`, set `NOTARIZE_KEYCHAIN_PROFILE=teximo-notarize` and **remove** `NOTARIZE_PASSWORD` so the password only lives in Keychain.

Alternatively, export the same variables in `~/.zshrc` instead of using `.env`.

## Quick Release

For a new version (e.g., 1.7.0):

```bash
# Build, sign, and notarize
./update_both.sh 1.7.0
```

This script will:
1. Build the app
2. **Sign the app with your Developer ID**
3. Create DMG
4. **Sign and notarize the DMG**
5. Update SHA256
6. Update both repositories
7. Push everything

## Manual Steps After Running Script

1. **Go to GitHub Releases**: https://github.com/dmrkv/teximo/releases
2. **Click "Edit"** on the latest release
3. **Upload new DMG**: `build/Teximo-1.7.0.dmg`
4. **Update release title**: `Teximo v1.7.0`
5. **Click "Update release"**

## What Gets Updated Automatically

- ✅ App code signing with Developer ID
- ✅ DMG code signing
- ✅ Apple notarization and ticket stapling
- ✅ Homebrew formula version
- ✅ SHA256 hash
- ✅ DMG filename
- ✅ Both GitHub repositories
- ✅ Git commits and pushes

## What You Need to Do Manually

- 📤 Upload DMG to GitHub release
- 📝 Update release title and description

## Signing and Notarization Only

If you just need to sign and notarize an existing build:

```bash
./sign_and_notarize.sh 1.7.0
```

## Testing the Release

### Test Code Signing

```bash
# Verify app signature
codesign --verify --deep --strict --verbose=2 build/Teximo.app

# Verify DMG signature
codesign --verify --verbose=2 Teximo-1.7.0.dmg

# Verify notarization staple
stapler validate Teximo-1.7.0.dmg

# Verify Gatekeeper acceptance
spctl -a -t exec -vv build/Teximo.app
```

### Test Homebrew Installation
```bash
brew install dmrkv/teximo/teximo
```

### Test DMG Installation
1. Download DMG from GitHub releases
2. Copy to Applications folder
3. **Launch without `xattr` workaround** - should work!
4. Test all app features

## File Locations

- **DMG**: `Teximo-{VERSION}.dmg`
- **Homebrew Formula**: `Formula/teximo.rb`
- **Homebrew Tap**: `/Users/dima/Dev/homebrew-teximo/`

## Troubleshooting

### "No Developer ID Application certificate found"

You have an Apple Development certificate but need Developer ID:
1. Open Xcode → Settings → Accounts
2. Select your Apple ID → Manage Certificates
3. Click '+' → **Developer ID Application**
4. Wait a few seconds for it to generate

### "Damaged and can't be opened" Error

This means the app isn't signed or notarized. Solutions:

**For Users (Temporary Workaround):**
```bash
sudo xattr -r -d com.apple.quarantine /Applications/Teximo.app
```

**For Developers (Proper Fix):**
Run the signing and notarization script:
```bash
./sign_and_notarize.sh 1.7.0
```

### Notarization Failed

Get detailed error log:
```bash
# After a failed notarization, use the submission ID from the output:
source scripts/release_credentials.sh && release_credentials_load
release_credentials_notarytool_log SUBMISSION_ID
```

Common issues:
- App not signed with hardened runtime
- Linking against old SDK (need macOS 10.9+)
- Missing timestamps in code signature

### If Homebrew Installation Fails
- Check that `homebrew-teximo` repository exists
- Verify SHA256 hash is correct
- Ensure DMG is uploaded to GitHub releases

### If DMG Installation Fails
- Verify code signature: `codesign --verify --deep build/Teximo.app`
- Check notarization: `stapler validate Teximo-1.7.0.dmg`
- Test on different macOS versions (10.13+)

