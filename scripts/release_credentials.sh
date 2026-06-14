#!/bin/bash
# Shared notarization credential loading for release scripts.
# Source this file; do not run it directly.

_release_credentials_repo_root() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cd "$script_dir/.." && pwd
}

release_credentials_load() {
    local root
    root="$(_release_credentials_repo_root)"
    if [[ -f "$root/.env" ]]; then
        set -a
        # shellcheck disable=SC1091
        source "$root/.env"
        set +a
    fi
}

release_credentials_print_help() {
    cat <<'EOF'
Notarization credentials are missing.

Option A — Keychain profile (recommended):
  1. Copy .env.example to .env and fill in NOTARIZE_APPLE_ID, NOTARIZE_TEAM_ID, NOTARIZE_PASSWORD
  2. Run: ./scripts/setup_notary_keychain.sh
  3. Set NOTARIZE_KEYCHAIN_PROFILE=teximo-notarize in .env (password can be removed after)

Option B — Environment / .env only:
  Copy .env.example to .env and set:
    NOTARIZE_APPLE_ID, NOTARIZE_TEAM_ID, NOTARIZE_PASSWORD

See RELEASE_GUIDE.md for app-specific password setup and rotation.
EOF
}

release_credentials_has_notary() {
    if [[ -n "${NOTARIZE_KEYCHAIN_PROFILE:-}" ]]; then
        return 0
    fi
    [[ -n "${NOTARIZE_APPLE_ID:-}" && -n "${NOTARIZE_TEAM_ID:-}" && -n "${NOTARIZE_PASSWORD:-}" ]]
}

release_credentials_require_notary() {
    if release_credentials_has_notary; then
        return 0
    fi
    release_credentials_print_help >&2
    return 1
}

# Usage: release_credentials_notarytool_submit /path/to/artifact.dmg
release_credentials_notarytool_submit() {
    local artifact="$1"
    if [[ -z "$artifact" ]]; then
        echo "release_credentials_notarytool_submit: missing artifact path" >&2
        return 1
    fi
    release_credentials_require_notary || return 1

    if [[ -n "${NOTARIZE_KEYCHAIN_PROFILE:-}" ]]; then
        xcrun notarytool submit "$artifact" \
            --keychain-profile "$NOTARIZE_KEYCHAIN_PROFILE" \
            --wait
    else
        xcrun notarytool submit "$artifact" \
            --apple-id "$NOTARIZE_APPLE_ID" \
            --team-id "$NOTARIZE_TEAM_ID" \
            --password "$NOTARIZE_PASSWORD" \
            --wait
    fi
}

# Usage: release_credentials_notarytool_log SUBMISSION_ID
release_credentials_notarytool_log() {
    local submission_id="$1"
    if [[ -z "$submission_id" ]]; then
        echo "release_credentials_notarytool_log: missing submission id" >&2
        return 1
    fi
    release_credentials_require_notary || return 1

    if [[ -n "${NOTARIZE_KEYCHAIN_PROFILE:-}" ]]; then
        xcrun notarytool log "$submission_id" --keychain-profile "$NOTARIZE_KEYCHAIN_PROFILE"
    else
        xcrun notarytool log "$submission_id" \
            --apple-id "$NOTARIZE_APPLE_ID" \
            --team-id "$NOTARIZE_TEAM_ID" \
            --password "$NOTARIZE_PASSWORD"
    fi
}
