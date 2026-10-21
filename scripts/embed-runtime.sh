#!/usr/bin/env bash
# Xcode post-build step for Hufu.app: copies librime.1.dylib and the assembled
# SharedSupport into the bundle.
set -euo pipefail
ROOT="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
APP="${TARGET_BUILD_DIR}/${WRAPPER_NAME}"
FRAMEWORKS="$APP/Contents/Frameworks"
mkdir -p "$FRAMEWORKS" "$APP/Contents/SharedSupport"

if [[ ! -f "$FRAMEWORKS/librime.1.dylib" ]]; then
  cp -L "$ROOT/Vendor/librime/lib/librime.1.dylib" "$FRAMEWORKS/"
fi
# A previous build may have left plugin dylibs in the product bundle.
rm -rf "$FRAMEWORKS/rime-plugins"

if [[ -d "$ROOT/build/SharedSupport" ]]; then
  rsync -a --delete "$ROOT/build/SharedSupport/" "$APP/Contents/SharedSupport/"
else
  echo "warning: build/SharedSupport missing — run scripts/stage-huma.sh" >&2
fi

# Embed license texts and third-party notices before code signing.
python3 "$ROOT/scripts/embed-license-materials.py" --app "$APP"

# Re-sign nested code with the app's identity.
IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:--}"
[[ -z "$IDENTITY" ]] && IDENTITY="-"
TIMESTAMP=--timestamp
[[ "$IDENTITY" == "-" ]] && TIMESTAMP=--timestamp=none
# The timestamp service is sometimes unreachable; this intermediate signature is
# replaced by build-app.sh anyway, so fall back to an untimestamped one.
codesign --force --options runtime --sign "$IDENTITY" "$TIMESTAMP" "$FRAMEWORKS/librime.1.dylib" >/dev/null 2>&1 \
  || codesign --force --options runtime --sign "$IDENTITY" --timestamp=none "$FRAMEWORKS/librime.1.dylib" >/dev/null
