#!/bin/bash

# Beautiful DMG Creator for Teximo
# Creates a DMG with custom background, Applications link, and proper layout

set -e

VERSION=${1:-"1.5.0"}
# Configuration
APP_NAME="Teximo"
VERSION="1.6.0"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
VOLUME_NAME="${APP_NAME}"
SOURCE_APP="build/${APP_NAME}.app"
DMG_BACKGROUND_IMG="/Users/dima/.gemini/antigravity/brain/626a2bb3-1c51-41ed-a2b2-f36a23820945/dmg_background.png"

echo "🎨 Creating beautiful DMG for ${APP_NAME} v${VERSION}..."

# Create temporary directory in project folder
TMP_DIR="./dmg_tmp"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"
TMP_DMG="$TMP_DIR/temp.dmg"

# Copy app to temp directory
cp -R "$SOURCE_APP" "$TMP_DIR/"

# Create Applications symlink
ln -s /Applications "$TMP_DIR/Applications"

# Create initial DMG
echo "📦 Creating initial DMG..."
hdiutil create -volname "$VOLUME_NAME" -srcfolder "$TMP_DIR" -ov -format UDRW "$TMP_DMG"

# Mount the DMG
echo "💿 Mounting DMG..."
MOUNT_DIR=$(hdiutil attach "$TMP_DMG" | grep -o "/Volumes/.*")

# Copy background image with arrow
echo "🎨 Adding background..."
mkdir -p "$MOUNT_DIR/.background"
cp "$DMG_BACKGROUND_IMG" "$MOUNT_DIR/.background/background.png"

# Set up the DMG window appearance with AppleScript
echo "⚙️  Configuring window layout..."
osascript <<EOF
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 700, 550}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 100
        set background picture of viewOptions to file ".background:background.png"
        
        -- Position icons at same y coordinate for perfect vertical alignment
        set position of item "$APP_NAME.app" of container window to {150, 221}
        set position of item "Applications" of container window to {450, 221}
        
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

# Unmount and convert to compressed DMG
echo "💾 Finalizing DMG..."
sync
hdiutil detach "$MOUNT_DIR"
hdiutil convert "$TMP_DMG" -format UDZO -o "$DMG_NAME"

# Clean up
rm -rf "$TMP_DIR"

echo ""
echo "✅ Beautiful DMG created: $DMG_NAME"
echo "📏 File size: $(du -h "$DMG_NAME" | cut -f1)"
echo ""
