#!/usr/bin/env bash
# Xcode post-build step for Hufu.app: embeds the assembled SharedSupport and
# license materials. librime is linked statically, so there is no Frameworks payload.
set -euo pipefail
ROOT="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
APP="${TARGET_BUILD_DIR}/${WRAPPER_NAME}"
mkdir -p "$APP/Contents/SharedSupport"

# Remove payloads left by earlier dynamic-linking builds.
rm -rf "$APP/Contents/Frameworks"

if [[ -d "$ROOT/build/SharedSupport" ]]; then
  rsync -a --delete "$ROOT/build/SharedSupport/" "$APP/Contents/SharedSupport/"
else
  echo "warning: build/SharedSupport missing — run scripts/stage-huma.sh" >&2
fi

# Embed license texts and third-party notices before code signing.
python3 "$ROOT/scripts/embed-license-materials.py" --app "$APP"
