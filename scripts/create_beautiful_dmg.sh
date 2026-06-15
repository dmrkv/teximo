#!/bin/bash
# Creates a styled Teximo DMG with background image and Applications drop link.
# Usage: create_beautiful_dmg.sh <path/to/Teximo.app> <output.dmg>

set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <Teximo.app> <output.dmg>" >&2
    exit 1
fi

APP_PATH="$1"
DMG_PATH="$2"
APP_NAME="Teximo"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKGROUND="${DMG_BACKGROUND:-$SCRIPT_DIR/../assets/dmg_background.png}"

if [[ ! -d "$APP_PATH" ]]; then
    echo "App not found: $APP_PATH" >&2
    exit 1
fi

if ! command -v create-dmg &>/dev/null; then
    echo "create-dmg is required. Install with: brew install create-dmg" >&2
    exit 1
fi

if [[ ! -f "$BACKGROUND" ]]; then
    echo "Background image not found: $BACKGROUND" >&2
    exit 1
fi

# Avoid stale mounts from failed runs
hdiutil detach "/Volumes/$APP_NAME" -force 2>/dev/null || true

rm -f "$DMG_PATH"

echo "Creating styled DMG..."
create-dmg \
    --volname "$APP_NAME" \
    --background "$BACKGROUND" \
    --window-pos 100 100 \
    --window-size 600 450 \
    --icon-size 100 \
    --icon "${APP_NAME}.app" 150 221 \
    --hide-extension "${APP_NAME}.app" \
    --app-drop-link 450 221 \
    --no-internet-enable \
    "$DMG_PATH" \
    "$APP_PATH"

echo "DMG created: $DMG_PATH"
