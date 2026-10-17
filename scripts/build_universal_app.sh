#!/bin/bash
# Build the universal app without changing existing development bundles.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
VERSION="$(awk '/MARKETING_VERSION:/ { print $2; exit }' project.yml)"
BUILD_NUMBER="$(awk '/CURRENT_PROJECT_VERSION:/ { print $2; exit }' project.yml)"
DEVELOPER_PATH="${DEVELOPER_DIR:-$(xcode-select -p)}"
SWIFTC="$DEVELOPER_PATH/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
SDK="$DEVELOPER_PATH/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
OUTPUT="$ROOT/build/release-$VERSION"
APP="$OUTPUT/Teximo.app"

if [[ ! -x "$SWIFTC" || ! -d "$SDK" ]]; then
    echo "Set DEVELOPER_DIR to a full Xcode Developer directory." >&2
    exit 1
fi
if [[ -e "$APP" ]]; then
    echo "Output already exists: $APP" >&2
    exit 1
fi
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$OUTPUT/AppIcon.iconset"

for ARCH in arm64 x86_64; do
    "$SWIFTC" -O -sdk "$SDK" -module-cache-path "$OUTPUT/module-cache" \
        -target "$ARCH-apple-macos13.0" -swift-version 5 \
        -Xfrontend -disable-sandbox Sources/Teximo/*.swift -o "$OUTPUT/Teximo-$ARCH"
done
"$DEVELOPER_PATH/Toolchains/XcodeDefault.xctoolchain/usr/bin/lipo" -create \
    "$OUTPUT/Teximo-arm64" "$OUTPUT/Teximo-x86_64" -output "$APP/Contents/MacOS/Teximo"

cp Sources/Teximo/Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable Teximo' "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier dev.teximo.app' "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"
cp Sources/Teximo/AppIcon.png "$APP/Contents/Resources/"
for SIZE in 16 32 128 256 512; do
    sips -z "$SIZE" "$SIZE" Sources/Teximo/AppIcon.png \
        --out "$OUTPUT/AppIcon.iconset/icon_${SIZE}x${SIZE}.png" >/dev/null
    DOUBLE=$((SIZE * 2))
    sips -z "$DOUBLE" "$DOUBLE" Sources/Teximo/AppIcon.png \
        --out "$OUTPUT/AppIcon.iconset/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
iconutil -c icns "$OUTPUT/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
"$APP/Contents/MacOS/Teximo" --version
echo "Built $APP (sign and notarize before publishing)."
