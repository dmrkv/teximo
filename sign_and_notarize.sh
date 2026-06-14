#!/bin/bash

# Teximo Code Signing and Notarization Script
# This script signs the app, creates a DMG, and notarizes it with Apple

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/release_credentials.sh
source "$SCRIPT_DIR/scripts/release_credentials.sh"
release_credentials_load

echo "🔐 Teximo Code Signing and Notarization"
echo "========================================"
echo ""

# Configuration
APP_NAME="Teximo"
VERSION=$( grep "MARKETING_VERSION:" project.yml | awk '{print $2}')
if [ -z "$VERSION" ]; then
    VERSION="1.7.1"
fi
BUILD_DIR="build"
APP_PATH="$BUILD_DIR/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"

# Check for required tools
if ! command -v codesign &> /dev/null; then
    echo "❌ Error: codesign not found. Please install Xcode Command Line Tools."
    exit 1
fi

if ! command -v xcrun &> /dev/null; then
    echo "❌ Error: xcrun not found. Please install Xcode."
    exit 1
fi

# Find Developer ID Application certificate
echo "🔍 Looking for Developer ID Application certificate..."
CERTIFICATE=$(security find-identity -v -p basic | grep "Developer ID Application" | head -1 | grep -o '".*"' | tr -d '"')

if [ -z "$CERTIFICATE" ]; then
    echo ""
    echo "❌ ERROR: No Developer ID Application certificate found!"
    echo ""
    echo "You need a Developer ID Application certificate to distribute outside the Mac App Store."
    echo ""
    echo "📋 To get one:"
    echo "  1. Ensure you have a paid Apple Developer Program membership ($99/year)"
    echo "  2. Open Xcode → Settings → Accounts"
    echo "  3. Select your Apple ID → Manage Certificates"
    echo "  4. Click '+' → Developer ID Application"
    echo ""
    echo "Note: You currently have an 'Apple Development' certificate, which is only for development,"
    echo "      not distribution. You need 'Developer ID Application' for distribution."
    echo ""
    exit 1
fi

echo "✅ Found certificate: $CERTIFICATE"
echo ""

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: App not found at $APP_PATH"
    echo "Please run build_release.sh first to build the app."
    exit 1
fi

echo "📝 Signing app bundle..."

# Sign the app with hardened runtime
codesign --force --deep \
    --options runtime \
    --sign "$CERTIFICATE" \
    --timestamp \
    "$APP_PATH"

echo "✅ App signed successfully"

# Verify the signature
echo ""
echo "🔍 Verifying signature..."
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
echo "✅ Signature verified"
echo ""

# Create DMG if it doesn't exist or if we need to recreate it
if [ -f "$DMG_PATH" ]; then
    echo "⚠️  DMG already exists. Removing old DMG..."
    rm -f "$DMG_PATH"
fi

echo "📦 Creating DMG..."
./create_release_dmg.sh

if [ ! -f "$DMG_PATH" ]; then
    echo "❌ Error: DMG creation failed"
    exit 1
fi

echo "✅ DMG created"
echo ""

# Sign the DMG
echo "📝 Signing DMG..."
codesign --force \
    --sign "$CERTIFICATE" \
    --timestamp \
    "$DMG_PATH"

echo "✅ DMG signed"

# Verify DMG signature
echo ""
echo "🔍 Verifying DMG signature..."
codesign --verify --verbose=2 "$DMG_PATH"
echo "✅ DMG signature verified"
echo ""

# Check for notarization credentials
echo "📤 Preparing for notarization..."
echo ""
echo "⚠️  NOTARIZATION SETUP REQUIRED:"
echo ""
echo "To notarize, you need to provide credentials in one of these ways:"
echo ""
echo "Option 1: .env file (recommended)"
echo "  cp .env.example .env   # then fill in values"
echo "  ./scripts/setup_notary_keychain.sh   # stores credentials in Keychain"
echo ""
echo "Option 2: Environment variables"
echo "  export NOTARIZE_APPLE_ID / NOTARIZE_TEAM_ID / NOTARIZE_PASSWORD"
echo "  or export NOTARIZE_KEYCHAIN_PROFILE=teximo-notarize"
echo ""
echo "Option 3: Interactive (you'll be prompted)"
echo "  Run this script without credentials configured"
echo ""
echo "To generate an app-specific password:"
echo "  1. Go to https://appleid.apple.com/account/manage"
echo "  2. Sign in with your Apple ID"
echo "  3. Under 'Security' → 'App-Specific Passwords' → Generate"
echo "  4. Name it 'Teximo Notarization' and copy the password"
echo ""

# Check if credentials are set
if ! release_credentials_has_notary; then
    echo "❓ Would you like to notarize now? (y/n)"
    read -r response
    
    if [[ "$response" != "y" ]]; then
        echo ""
        echo "⏭️  Skipping notarization."
        echo ""
        echo "✅ CODE SIGNING COMPLETE"
        echo ""
        echo "⚠️  WARNING: Without notarization, users will still see Gatekeeper warnings!"
        echo ""
        echo "To notarize later, set the environment variables and run:"
        echo "  ./sign_and_notarize.sh $VERSION"
        echo ""
        exit 0
    fi
    
    echo ""
    echo "Please enter your notarization credentials:"
    read -p "Apple ID: " NOTARIZE_APPLE_ID
    read -p "Team ID: " NOTARIZE_TEAM_ID
    read -s -p "App-Specific Password: " NOTARIZE_PASSWORD
    echo ""
fi

# Submit for notarization
echo ""
echo "☁️  Submitting to Apple for notarization..."
echo "(This may take several minutes...)"
echo ""

# Stream output to console AND file so user sees progress
release_credentials_notarytool_submit "$DMG_PATH" 2>&1 | tee notarization_log.txt || true

NOTARIZE_OUTPUT=$(cat notarization_log.txt)
rm notarization_log.txt

# echo "$NOTARIZE_OUTPUT" # Already printed by tee

if echo "$NOTARIZE_OUTPUT" | grep -q "status: Accepted"; then
    echo ""
    echo "✅ Notarization successful!"
    echo ""
    
    # Staple the notarization ticket
    echo "📎 Stapling notarization ticket to DMG..."
    xcrun stapler staple "$DMG_PATH"
    echo "✅ Ticket stapled"
    echo ""
    
    # Verify stapling
    echo "🔍 Verifying stapled ticket..."
    xcrun stapler validate "$DMG_PATH"
    echo "✅ Ticket verified"
    echo ""
    
    # Final Gatekeeper check
    echo "🔍 Final Gatekeeper verification..."
    spctl -a -t open --context context:primary-signature -v "$DMG_PATH"
    echo "✅ Gatekeeper will accept this DMG"
    echo ""
    
    echo "🎉 SUCCESS! Your DMG is fully signed and notarized!"
    echo ""
    echo "📁 DMG: $DMG_PATH"
    echo "📏 Size: $(du -h "$DMG_PATH" | cut -f1)"
    echo ""
    echo "Users can now install this without any 'damaged' warnings! 🚀"
    
elif echo "$NOTARIZE_OUTPUT" | grep -q "status: Invalid"; then
    echo ""
    echo "❌ Notarization failed: Invalid"
    echo ""
    echo "Common causes:"
    echo "  - App not signed with hardened runtime"
    echo "  - Missing entitlements"
    echo "  - Code signing issues"
    echo ""
    echo "Get detailed log:"
    SUBMISSION_ID=$(echo "$NOTARIZE_OUTPUT" | grep "id:" | head -1 | awk '{print $2}')
    if [ -n "$SUBMISSION_ID" ]; then
        echo "  source scripts/release_credentials.sh && release_credentials_load"
        echo "  release_credentials_notarytool_log $SUBMISSION_ID"
    fi
    echo ""
    exit 1
else
    echo ""
    echo "❌ Notarization failed with unexpected status"
    echo "Check the output above for details"
    exit 1
fi
