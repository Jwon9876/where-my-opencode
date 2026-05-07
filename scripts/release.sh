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

build_app() {
    xcodebuild build \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination platform=macOS \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        CODE_SIGNING_ALLOWED=NO
}

ad_hoc_sign_app() {
    local app_path="$1"

    codesign --force --deep --sign - "$app_path"
    codesign --verify --deep --strict --verbose=2 "$app_path"
}

create_zip() {
    local app_path="$1"
    local zip_path="$2"

    rm -f "$zip_path"
    ditto -c -k --sequesterRsrc --keepParent "$app_path" "$zip_path"
}

checksum() {
    local asset_path="$1"
    (
        cd "$(dirname "$asset_path")"
        shasum -a 256 "$(basename "$asset_path")" >"$(basename "$asset_path").sha256"
    )
}

verify_zip_distribution() {
    local zip_path="$1"
    local verify_dir="$WORK_DIR/verify"
    local extracted_app="$verify_dir/$APP_NAME.app"

    rm -rf "$verify_dir"
    mkdir -p "$verify_dir"

    echo "Verifying ZIP extraction..."
    ditto -x -k "$zip_path" "$verify_dir"
    validate_app "$extracted_app"
    codesign --verify --deep --strict --verbose=2 "$extracted_app"
}

main() {
    cd "$REPO_ROOT"

    require_tool xcodebuild
    require_tool shasum
    require_tool plutil
    require_tool ditto
    require_tool codesign

    local version="${VERSION:-$(marketing_version)}"
    [[ -n "$version" ]] || fail "Could not resolve MARKETING_VERSION."

    local dist_dir="${DIST_DIR:-$REPO_ROOT/dist/$version}"
    local products_dir="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION"
    local built_app="$products_dir/$APP_NAME.app"
    local stage_dir="$WORK_DIR/stage"
    local staged_app="$stage_dir/$APP_NAME.app"
    local version_label="$version"
    local zip_path

    case "$version_label" in
        v*) ;;
        *) version_label="v$version_label" ;;
    esac

    zip_path="$dist_dir/Where-My-OpenCode-$version_label-macOS-unsigned.zip"

    clean_work_dir
    mkdir -p "$dist_dir" "$stage_dir"

    echo "Building $APP_NAME $version..."
    build_app
    validate_app "$built_app"

    echo "Preparing release app bundle..."
    ditto "$built_app" "$staged_app"
    validate_app "$staged_app"

    echo "Applying ad-hoc signature..."
    ad_hoc_sign_app "$staged_app"

    echo "Creating $zip_path..."
    create_zip "$staged_app" "$zip_path"
    verify_zip_distribution "$zip_path"
    checksum "$zip_path"

    echo "Release assets:"
    echo "  $zip_path"
    echo "  $zip_path.sha256"
    echo
    echo "This ZIP is unsigned and not notarized. Users should move the app to /Applications,"
    echo "then Control-click the app and choose Open the first time they launch it."
}

main "$@"
