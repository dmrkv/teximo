#!/bin/bash
set -e

DMG_PATH="$1"

if [ -z "$DMG_PATH" ]; then
    echo "Usage: ./deploy_release.sh <path_to_dmg>"
    exit 1
fi

if [ ! -f "$DMG_PATH" ]; then
    echo "❌ DMG not found at $DMG_PATH"
    exit 1
fi

# Extract version from filename (Teximo-1.7.1.dmg -> 1.7.1)
FILENAME=$(basename "$DMG_PATH")
VERSION=$(echo "$FILENAME" | sed -E 's/Teximo-(.*)\.dmg/\1/')

echo "🚀 Deploying $FILENAME (Version $VERSION)..."

# 1. Calculate SHA256
echo "🔐 Calculating SHA256..."
SHA256=$(shasum -a 256 "$DMG_PATH" | cut -d' ' -f1)
echo "   SHA256: $SHA256"

# 2. Update Homebrew Formula
FORMULA_PATH="Formula/teximo.rb"
if [ ! -f "$FORMULA_PATH" ]; then
    echo "❌ Formula not found at $FORMULA_PATH"
    exit 1
fi

echo "🍺 Updating Homebrew formula..."
sed -i '' "s/version \".*\"/version \"$VERSION\"/" "$FORMULA_PATH"
sed -i '' "s/sha256 \".*\"/sha256 \"$SHA256\"/" "$FORMULA_PATH"
# Ensure URL points to the new release asset
sed -i '' "s|url \".*\"|url \"https://github.com/dmrkv/teximo/releases/download/v${VERSION}/Teximo-${VERSION}.dmg\"|" "$FORMULA_PATH"

# 3. Git Commit & Push
echo "📝 Committing Homebrew update..."
git add "$FORMULA_PATH"
git commit -m "Update formula to v$VERSION"
git push

# 4. GitHub Release
echo "⬆️ Creating GitHub Release..."
# Check if release exists
if gh release view "v$VERSION" >/dev/null 2>&1; then
    echo "⚠️  Release v$VERSION already exists. Uploading asset only..."
    gh release upload "v$VERSION" "$DMG_PATH" --clobber
else
    echo "✨ Creating new release release v$VERSION..."
    gh release create "v$VERSION" "$DMG_PATH" --title "v$VERSION" --generate-notes
fi

echo "✅ Deployment Complete!"
