#!/usr/bin/env bash
set -euo pipefail

PROJECT="WhereMyOpenCode.xcodeproj"
SCHEME="WhereMyOpenCode"
CONFIGURATION="${CONFIGURATION:-Release}"
APP_NAME="Where My OpenCode"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/private/tmp/where-my-opencode-release-derived-data}"
WORK_DIR="${WORK_DIR:-/private/tmp/where-my-opencode-release-work}"

fail() {
    echo "error: $*" >&2
    exit 1
}

require_tool() {
    command -v "$1" >/dev/null 2>&1 || fail "Missing required tool: $1"
}

marketing_version() {
    xcodebuild \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -showBuildSettings 2>/dev/null |
        awk -F= '/MARKETING_VERSION/ {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
            print $2
            exit
        }'
}

clean_work_dir() {
    case "$WORK_DIR" in
        /private/tmp/where-my-opencode-*|/tmp/where-my-opencode-*) ;;
        *) fail "Refusing to clean unexpected WORK_DIR: $WORK_DIR" ;;
    esac

    rm -rf "$WORK_DIR"
    mkdir -p "$WORK_DIR"
}

validate_app() {
    local app_path="$1"
    local executable="$app_path/Contents/MacOS/$APP_NAME"
    local info_plist="$app_path/Contents/Info.plist"

    [[ -d "$app_path" ]] || fail "Missing app bundle: $app_path"
    [[ -f "$executable" ]] || fail "Missing app executable: $executable"
    [[ -f "$info_plist" ]] || fail "Missing app Info.plist: $info_plist"
    plutil -lint "$info_plist" >/dev/null
}

notary_args() {
    if [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
        NOTARY_ARGS=(--keychain-profile "$NOTARY_KEYCHAIN_PROFILE")
    elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
        NOTARY_ARGS=(
            --apple-id "$APPLE_ID"
            --team-id "$APPLE_TEAM_ID"
            --password "$APPLE_APP_SPECIFIC_PASSWORD"
        )
    else
        fail "DEVELOPER_ID_APPLICATION is set, but notarization credentials are missing. Set NOTARY_KEYCHAIN_PROFILE or APPLE_ID, APPLE_TEAM_ID, and APPLE_APP_SPECIFIC_PASSWORD."
    fi
}

build_app() {
    xcodebuild build \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination platform=macOS \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        CODE_SIGNING_ALLOWED=NO
}

create_dmg() {
    local source_dir="$1"
    local dmg_path="$2"
    local volume_name="$3"

    rm -f "$dmg_path"
    hdiutil create \
        -volname "$volume_name" \
        -srcfolder "$source_dir" \
        -ov \
        -format UDZO \
        "$dmg_path"
}

checksum() {
    local dmg_path="$1"
    (
        cd "$(dirname "$dmg_path")"
        shasum -a 256 "$(basename "$dmg_path")" >"$(basename "$dmg_path").sha256"
    )
}

main() {
    cd "$REPO_ROOT"

    require_tool xcodebuild
    require_tool hdiutil
    require_tool shasum
    require_tool plutil

    local version="${VERSION:-$(marketing_version)}"
    [[ -n "$version" ]] || fail "Could not resolve MARKETING_VERSION."

    local dist_dir="${DIST_DIR:-$REPO_ROOT/dist/$version}"
    local products_dir="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION"
    local built_app="$products_dir/$APP_NAME.app"
    local stage_dir="$WORK_DIR/stage"
    local staged_app="$stage_dir/$APP_NAME.app"
    local signed=0
    local dmg_name="$APP_NAME-unsigned.dmg"
    local dmg_path

    if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
        signed=1
        dmg_name="$APP_NAME.dmg"
        notary_args
        require_tool codesign
        require_tool xcrun
        require_tool spctl
    fi

    clean_work_dir
    mkdir -p "$dist_dir" "$stage_dir"

    echo "Building $APP_NAME $version..."
    build_app
    validate_app "$built_app"

    echo "Preparing DMG staging area..."
    ditto "$built_app" "$staged_app"
    ln -s /Applications "$stage_dir/Applications"
    validate_app "$staged_app"

    if [[ "$signed" -eq 1 ]]; then
        echo "Signing app with $DEVELOPER_ID_APPLICATION..."
        codesign --force --deep --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$staged_app"
        codesign --verify --deep --strict --verbose=2 "$staged_app"
    else
        echo "Developer ID environment not found; creating unsigned development DMG."
    fi

    dmg_path="$dist_dir/$dmg_name"
    echo "Creating $dmg_path..."
    create_dmg "$stage_dir" "$dmg_path" "$APP_NAME"

    if [[ "$signed" -eq 1 ]]; then
        echo "Signing DMG..."
        codesign --force --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$dmg_path"
        codesign --verify --verbose=2 "$dmg_path"

        echo "Submitting DMG for notarization..."
        xcrun notarytool submit "$dmg_path" "${NOTARY_ARGS[@]}" --wait

        echo "Stapling notarization ticket..."
        xcrun stapler staple "$dmg_path"
        xcrun stapler validate "$dmg_path"
        spctl -a -t open --context context:primary-signature -v "$dmg_path"
    fi

    checksum "$dmg_path"

    echo "Release assets:"
    echo "  $dmg_path"
    echo "  $dmg_path.sha256"
}

NOTARY_ARGS=()
main "$@"
