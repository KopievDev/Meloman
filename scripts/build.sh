#!/usr/bin/env bash
# Produce a local, unsigned macOS .app and a downloadable ZIP.
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
DERIVED_DATA="${ROOT_DIR}/.build/MelomanDerivedData"
CONFIGURATION="Release"
RUN_APP=false

usage() {
    cat <<'HELP'
Usage: ./scripts/build.sh [--release|--debug] [--run]

Build Meloman with Tuist and Xcode, then copy the unsigned app to
  dist/Meloman.app
  dist/Meloman-macOS-<configuration>-unsigned.zip

--release  Release build (default)
--debug    Debug build
--run      Launch the built .app after packaging
--help     Show this help

Requires macOS, Xcode and mise. Installs the pinned Tuist version if needed.
HELP
}

for arg in "$@"; do
    case "$arg" in
        --release) CONFIGURATION="Release" ;;
        --debug) CONFIGURATION="Debug" ;;
        --run) RUN_APP=true ;;
        --help|-h) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$arg" >&2; usage >&2; exit 2 ;;
    esac
done

for tool in mise xcodebuild ditto; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'Required tool is missing: %s\n' "$tool" >&2
        exit 1
    fi
done

cd "$ROOT_DIR"

printf '\n==> Install project tools (mise)\n'
mise install

printf '\n==> Generate Tuist workspace\n'
mise exec -- tuist generate --no-open

printf '\n==> Build %s with xcodebuild\n' "$CONFIGURATION"
xcodebuild \
    -workspace "${ROOT_DIR}/Meloman.xcworkspace" \
    -scheme "Meloman" \
    -configuration "$CONFIGURATION" \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO \
    build

BUILT_APP="${DERIVED_DATA}/Build/Products/${CONFIGURATION}/Meloman.app"
FINAL_APP="${DIST_DIR}/Meloman.app"
ZIP_PATH="${DIST_DIR}/Meloman-macOS-${CONFIGURATION}-unsigned.zip"

if [[ ! -x "${BUILT_APP}/Contents/MacOS/Meloman" ]]; then
    printf 'Expected executable not found: %s\n' "${BUILT_APP}/Contents/MacOS/Meloman" >&2
    exit 1
fi

printf '\n==> Package app\n'
mkdir -p "$DIST_DIR"
rm -rf "$FINAL_APP"
ditto "$BUILT_APP" "$FINAL_APP"
rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$FINAL_APP" "$ZIP_PATH"

printf '\nBuild completed successfully.\n'
printf 'App:    %s\n' "$FINAL_APP"
printf 'Binary: %s\n' "${FINAL_APP}/Contents/MacOS/Meloman"
printf 'ZIP:    %s\n' "$ZIP_PATH"
printf 'Note: This build is unsigned and not notarized; it is for local testing.\n'

if "$RUN_APP"; then
    open "$FINAL_APP"
fi
