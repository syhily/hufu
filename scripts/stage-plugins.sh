#!/usr/bin/env bash
# librime loads plugins from a `rime-plugins` directory next to librime.1.dylib.
# SwiftPM copies the dylib into its build products; put the plugins beside it so
# `swift run hufu` and `swift test` get the lua plugin too. Only librime-lua is
# vendored (octagram/predict are excluded by scripts/fetch-librime.sh).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLUGINS="$ROOT/Vendor/librime/lib/rime-plugins"
[[ -d "$PLUGINS" ]] || { echo "run scripts/fetch-librime.sh first" >&2; exit 1; }
find "$ROOT/Packages/HufuKit/.build" -name librime.1.dylib -not -path '*/artifacts/*' -not -path '*.xcframework/*' 2>/dev/null | while read -r lib; do
  dir="$(dirname "$lib")"
  rm -rf "$dir/rime-plugins" && cp -R "$PLUGINS" "$dir/rime-plugins"
  echo "staged plugins in $dir"
done
