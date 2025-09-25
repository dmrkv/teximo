#!/bin/bash

# Teximo Build and Distribution Script
# This script builds a release version and creates a distributable DMG

set -e

echo "🚀 Building Teximo for distribution..."

# Configuration
APP_NAME="Teximo"
BUNDLE_ID="dev.teximo.app"
VERSION=$(defaults read "$(pwd)/Teximo.xcodeproj/project.pbxproj" CFBundleShortVersionString 2>/dev/null || echo "1.0.0")
BUILD_DIR="build"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build the app
echo "🔨 Building app..."
xcodebuild -project Teximo.xcodeproj \
           -scheme Teximo \
           -configuration Release \
           -derivedDataPath "$BUILD_DIR/DerivedData" \
           build

# Find the built app
APP_PATH=$(find "$BUILD_DIR/DerivedData" -name "*.app" -type d | head -1)

if [ -z "$APP_PATH" ]; then
    echo "❌ Error: Could not find built app"
    exit 1
fi

echo "✅ App built successfully: $APP_PATH"

# Create DMG
echo "📦 Creating DMG..."

# Create a temporary directory for DMG contents
DMG_TEMP_DIR="$BUILD_DIR/dmg_temp"
mkdir -p "$DMG_TEMP_DIR"

# Copy app to temp directory
cp -R "$APP_PATH" "$DMG_TEMP_DIR/"

# Create Applications symlink
ln -s /Applications "$DMG_TEMP_DIR/Applications"

# Create DMG
hdiutil create -volname "$APP_NAME" \
               -srcfolder "$DMG_TEMP_DIR" \
               -ov -format UDZO \
               "$DMG_PATH"

# Clean up temp directory
rm -rf "$DMG_TEMP_DIR"

echo "✅ DMG created: $DMG_PATH"

# Get file size
FILE_SIZE=$(du -h "$DMG_PATH" | cut -f1)
echo "📊 DMG size: $FILE_SIZE"

echo ""
echo "🎉 Build complete!"
echo "📁 DMG location: $DMG_PATH"
echo "📤 Ready for distribution!"
echo ""
echo "To distribute:"
echo "1. Upload the DMG to GitHub Releases"
echo "2. Or share the DMG file directly with friends"
echo "3. Users can drag the app from the DMG to their Applications folder"
