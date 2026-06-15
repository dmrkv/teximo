#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/release_credentials.sh
source "$SCRIPT_DIR/scripts/release_credentials.sh"
release_credentials_load

APP_NAME="Teximo"
SCHEME_NAME="Teximo"
ENTITLEMENTS="Teximo.entitlements"
BUILD_DIR="$(pwd)/build"
APP_PATH="$BUILD_DIR/$APP_NAME.app"

if [[ -z "${SIGNING_IDENTITY:-}" ]]; then
    SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | grep -o '".*"' | tr -d '"')
fi
if [[ -z "$SIGNING_IDENTITY" ]]; then
    echo "No Developer ID Application certificate found. Install one in Xcode → Settings → Accounts." >&2
    exit 1
fi

echo "Using signing identity: $SIGNING_IDENTITY"
echo "Starting Release Build & Notarization for $APP_NAME"

echo "Building Release Configuration..."
rm -rf "$BUILD_DIR"

xcodebuild -scheme "$SCHEME_NAME" \
    -configuration Release \
    clean build \
    CONFIGURATION_BUILD_DIR="$BUILD_DIR" \
    CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
    CODE_SIGN_STYLE=Manual \
    -quiet

if [ ! -d "$APP_PATH" ]; then
    echo "Build failed: $APP_PATH not found." >&2
    exit 1
fi

VERSION=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString)
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
echo "App Version: $VERSION"

echo "Signing Application with Hardened Runtime..."

if [ -d "$APP_PATH/Contents/Frameworks" ]; then
    find "$APP_PATH/Contents/Frameworks" -type f \( -name "*.framework" -o -name "*.dylib" \) | while read -r framework; do
        codesign --force --verify --verbose --timestamp --options runtime --sign "$SIGNING_IDENTITY" "$framework"
    done
fi

codesign --force --verify --verbose --timestamp --options runtime \
    --sign "$SIGNING_IDENTITY" \
    --entitlements "$ENTITLEMENTS" \
    --deep \
    "$APP_PATH"

echo "Signed $APP_NAME.app"

echo "Creating DMG..."
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
"$SCRIPT_DIR/scripts/create_beautiful_dmg.sh" "$APP_PATH" "$DMG_NAME"

echo "Signing DMG..."
codesign --force --verify --verbose --timestamp \
    --sign "$SIGNING_IDENTITY" \
    "$DMG_NAME"

release_credentials_require_notary || exit 1

echo "Submitting for Notarization (this may take a few minutes)..."
release_credentials_notarytool_submit "$DMG_NAME"

echo "Stapling Notarization Ticket..."
xcrun stapler staple "$DMG_NAME"

echo "SUCCESS! $DMG_NAME is signed, notarized, and ready to distribute."
