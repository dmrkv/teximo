#!/bin/bash

# Teximo Release Update Script
# This script updates both DMG and Homebrew formula

set -e

VERSION=$1
if [ -z "$VERSION" ]; then
    echo "Usage: ./update_release.sh <version>"
    echo "Example: ./update_release.sh 1.1.0"
    exit 1
fi

echo "🚀 Updating Teximo release to v$VERSION"
echo "======================================"

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

# 5. Commit changes
echo "📝 Committing changes..."
git add Formula/teximo.rb
git commit -m "Update to version $VERSION

- Update DMG to Teximo-$VERSION.dmg
- Update SHA256 hash: $SHA256
- Update version to $VERSION"

# 6. Push to GitHub
echo "⬆️ Pushing to GitHub..."
git push

echo ""
echo "✅ Release updated successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Go to https://github.com/dmrkv/teximo/releases"
echo "2. Click 'Edit' on the latest release"
echo "3. Upload the new DMG: build/Teximo-$VERSION.dmg"
echo "4. Update release title to 'Teximo v$VERSION'"
echo "5. Click 'Update release'"
echo ""
echo "🍺 Homebrew formula updated automatically!"
echo "Users can now run: brew upgrade teximo"
