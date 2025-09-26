#!/bin/bash

# Teximo Homebrew Update Script
# This script updates the Homebrew formula for new releases

set -e

VERSION=$1
if [ -z "$VERSION" ]; then
    echo "Usage: ./update_homebrew.sh <version>"
    echo "Example: ./update_homebrew.sh 1.1.0"
    exit 1
fi

echo "🚀 Updating Teximo to v$VERSION"
echo "=============================="

# 1. Build the app
echo "📦 Building release version..."
xcodebuild -project Teximo.xcodeproj -scheme Teximo -configuration Release build

# 2. Create DMG
echo "💿 Creating DMG..."
rm -rf build/Teximo-$VERSION.dmg
hdiutil create -volname "Teximo" -srcfolder build/exported/Teximo.app -ov -format UDZO build/Teximo-$VERSION.dmg

# 3. Calculate SHA256
echo "🔐 Calculating SHA256..."
SHA256=$(shasum -a 256 build/Teximo-$VERSION.dmg | cut -d' ' -f1)
echo "SHA256: $SHA256"

# 4. Update Homebrew formula
echo "🍺 Updating Homebrew formula..."
sed -i '' "s/version \".*\"/version \"$VERSION\"/" Formula/teximo.rb
sed -i '' "s/sha256 \".*\"/sha256 \"$SHA256\"/" Formula/teximo.rb
sed -i '' "s/Teximo-.*\.dmg/Teximo-$VERSION.dmg/" Formula/teximo.rb

# 5. Update main repository
echo "📝 Committing changes to main repository..."
git add Formula/teximo.rb
git commit -m "Update to version $VERSION

- Update DMG to Teximo-$VERSION.dmg
- Update SHA256 hash: $SHA256
- Update version to $VERSION"

git push

# 6. Update Homebrew tap
echo "🍺 Updating Homebrew tap..."
cd /Users/dima/Dev/homebrew-teximo
cp /Users/dima/Dev/teximo/Formula/teximo.rb Formula/
git add Formula/teximo.rb
git commit -m "Update to version $VERSION"
git push

echo ""
echo "✅ Teximo v$VERSION released successfully!"
echo ""
echo "🎉 Users can now run:"
echo "   brew upgrade teximo"
echo ""
echo "📋 What was updated:"
echo "   - Homebrew formula version: $VERSION"
echo "   - SHA256 hash: $SHA256"
echo "   - DMG file: Teximo-$VERSION.dmg"
