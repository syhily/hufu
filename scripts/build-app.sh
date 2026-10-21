#!/usr/bin/env bash
# Builds and assembles a complete, signed Hufu.app at build/Release/Hufu.app:
#   Contents/MacOS/Hufu                      input method
#   Contents/Helpers/hufu                    CLI (+ its resource bundle)
#   Contents/Applications/Hufu Settings.app  settings
#   Contents/SharedSupport                   dictionaries, OpenCC data, prebuilt rime data
# librime is linked statically into the input method and CLI; no Frameworks payload.
# Used by install-dev.sh and package.sh. Signs ad-hoc unless HUFU_SIGN_IDENTITY is set.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${CONFIG:-Release}"
DERIVED="$ROOT/build/DerivedData"
OUT="$ROOT/build/Release"
IDENTITY="${HUFU_SIGN_IDENTITY:--}"

cd "$ROOT"
bash scripts/build-librime.sh
[[ -f build/SharedSupport/default.yaml ]] || bash scripts/stage-huma.sh
# Hufu's own data changes more often than the dictionaries: always refresh it.
ditto SharedSupport build/SharedSupport
# Refresh public metadata even when reusing an older dictionary build cache.
/usr/bin/python3 scripts/dictionary-metadata.py --shared-dir build/SharedSupport
command -v xcodegen >/dev/null || { echo "xcodegen is required: brew install xcodegen" >&2; exit 1; }
xcodegen generate --quiet

echo "==> building apps ($CONFIG)"
xcodebuild -project Hufu.xcodeproj -scheme Hufu -configuration "$CONFIG" -derivedDataPath "$DERIVED" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$IDENTITY" CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO build -quiet
BUILT="$DERIVED/Build/Products/$CONFIG"

echo "==> building CLI (universal: arm64 + x86_64)"
# Per-arch builds + lipo: SwiftPM's multi-arch mode misresolves the CRime
# xcframework's universal slice for the non-native arch (library not found).
swift build --package-path Packages/HufuKit -c release --product hufu --arch x86_64 >/dev/null
swift build --package-path Packages/HufuKit -c release --product hufu --arch arm64 >/dev/null
CLI_X64="$(swift build --package-path Packages/HufuKit -c release --arch x86_64 --show-bin-path)"
CLI_ARM="$(swift build --package-path Packages/HufuKit -c release --arch arm64 --show-bin-path)"
CLI_DIR="$ROOT/build/cli-universal"
rm -rf "$CLI_DIR" && mkdir -p "$CLI_DIR"
lipo -create "$CLI_X64/hufu" "$CLI_ARM/hufu" -output "$CLI_DIR/hufu"
ditto "$CLI_ARM/HufuKit_HufuCore.bundle" "$CLI_DIR/HufuKit_HufuCore.bundle"
lipo -info "$CLI_DIR/hufu" | grep -q "x86_64 arm64" || { echo "error: CLI is not a universal binary" >&2; exit 1; }

rm -rf "$OUT" && mkdir -p "$OUT"
APP="$OUT/Hufu.app"
ditto "$BUILT/Hufu.app" "$APP"
# Ensure no stale dylib payload survives an incremental build.
rm -rf "$APP/Contents/Frameworks"
# Not Contents/MacOS: the file system is case-insensitive and "hufu" would replace "Hufu".
mkdir -p "$APP/Contents/Helpers" "$APP/Contents/Applications"
cp "$CLI_DIR/hufu" "$APP/Contents/Helpers/hufu"
ditto "$CLI_DIR/HufuKit_HufuCore.bundle" "$APP/Contents/Helpers/HufuKit_HufuCore.bundle"
ditto "$BUILT/Hufu Settings.app" "$APP/Contents/Applications/Hufu Settings.app"

# Keep CFBundleShortVersionString numeric, but retain the full SemVer for updates.
# This only modifies staging bundles, before signing; project/CLI versions stay unchanged.
if [[ -n "${HUFU_RELEASE_VERSION:-}" ]]; then
  for bundle in "$APP" "$APP/Contents/Applications/Hufu Settings.app"; do
    plutil -replace HufuReleaseVersion -string "$HUFU_RELEASE_VERSION" "$bundle/Contents/Info.plist"
  done
fi

# Local builds are signed ad-hoc by default. Set HUFU_SIGN_IDENTITY to a certificate
# hash to use a real identity — but make sure it is not revoked: macOS treats code
# signed with a revoked certificate as malware (kills it and moves the app to Trash).
echo "==> signing with: $IDENTITY"
TIMESTAMP=--timestamp
[[ "$IDENTITY" == "-" ]] && TIMESTAMP=--timestamp=none
# Development builds tolerate an unreachable timestamp service; release packaging sets
# HUFU_REQUIRE_TIMESTAMP=1 (notarization needs secure timestamps).
sign() {
  codesign --force --options runtime "$TIMESTAMP" --sign "$IDENTITY" "$@" 2>/dev/null && return 0
  [[ "${HUFU_REQUIRE_TIMESTAMP:-0}" == 1 ]] && { echo "timestamp service unavailable" >&2; return 1; }
  codesign --force --options runtime --timestamp=none --sign "$IDENTITY" "$@"
}
sign "$APP/Contents/Helpers/HufuKit_HufuCore.bundle"
sign --entitlements Apps/Hufu/Hufu.entitlements "$APP/Contents/Helpers/hufu"
sign --entitlements Apps/HufuSettings/HufuSettings.entitlements "$APP/Contents/Applications/Hufu Settings.app"
sign --entitlements Apps/Hufu/Hufu.entitlements "$APP"
codesign --verify --deep --strict "$APP"
echo "==> built $APP"
