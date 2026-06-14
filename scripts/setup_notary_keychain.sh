#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=release_credentials.sh
source "$SCRIPT_DIR/release_credentials.sh"

PROFILE_NAME="${NOTARIZE_KEYCHAIN_PROFILE:-teximo-notarize}"

release_credentials_load

if [[ -z "${NOTARIZE_APPLE_ID:-}" || -z "${NOTARIZE_TEAM_ID:-}" || -z "${NOTARIZE_PASSWORD:-}" ]]; then
    echo "Set NOTARIZE_APPLE_ID, NOTARIZE_TEAM_ID, and NOTARIZE_PASSWORD in .env first." >&2
    echo "Copy .env.example to .env and fill in your values." >&2
    exit 1
fi

echo "Storing notarization credentials in Keychain profile: $PROFILE_NAME"
xcrun notarytool store-credentials "$PROFILE_NAME" \
    --apple-id "$NOTARIZE_APPLE_ID" \
    --team-id "$NOTARIZE_TEAM_ID" \
    --password "$NOTARIZE_PASSWORD"

echo ""
echo "Done. Add this to your .env (you can delete NOTARIZE_PASSWORD afterward):"
echo "NOTARIZE_KEYCHAIN_PROFILE=$PROFILE_NAME"
