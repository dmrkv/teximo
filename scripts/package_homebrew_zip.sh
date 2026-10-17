#!/bin/bash
# Package the stapled app for Homebrew without requiring a disk-image mount.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
VERSION="$(awk '/MARKETING_VERSION:/ { print $2; exit }' project.yml)"
OUTPUT="$ROOT/build/release-$VERSION"
APP="$OUTPUT/Teximo.app"
ARCHIVE="$OUTPUT/Teximo-$VERSION.zip"
DEVELOPER_PATH="${DEVELOPER_DIR:-$(xcode-select -p)}"
if [[ -e "$ARCHIVE" ]]; then
    echo "Archive already exists: $ARCHIVE" >&2
    exit 1
fi
"$DEVELOPER_PATH/usr/bin/stapler" validate "$APP"
STAGING="$(mktemp -d "$OUTPUT/homebrew-stage.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP" "$STAGING/Teximo.app"
cp LICENSE "$STAGING/LICENSE"
# Keep the archive free of AppleDouble sidecars: unzip would otherwise leave
# those extra files inside the signed bundle and invalidate its resource seal.
(cd "$STAGING" && COPYFILE_DISABLE=1 /usr/bin/zip -q -r -X "$ARCHIVE" Teximo.app LICENSE)
/usr/bin/unzip -q "$ARCHIVE" -d "$STAGING/verify"
codesign --verify --deep --strict "$STAGING/verify/Teximo.app"
"$DEVELOPER_PATH/usr/bin/stapler" validate "$STAGING/verify/Teximo.app"
shasum -a 256 "$ARCHIVE"
