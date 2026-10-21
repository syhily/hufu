#!/usr/bin/env bash
# Downloads the pinned librime prebuilt release and static xcframework, verifies
# sha256 and assembles Vendor/librime/{lib,bin,share,static} plus a static
# Packages/HufuKit/Frameworks/CRime.xcframework.
# The dynamic librime.1.dylib stays in Vendor/lib only so rime_deployer and the
# other staging tools can run; the app and CLI link the static archive.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$ROOT/Vendor"
LOCK="$VENDOR/librime.lock"
# shellcheck disable=SC1090
eval "$(grep -E '^LIBRIME_(VERSION|COMMIT)=|^RIME_PACK_TAG=' "$LOCK")"

BASE="https://github.com/rime/librime/releases/download/${LIBRIME_VERSION}"
ENGINE="rime-${LIBRIME_COMMIT}-macOS-universal.tar.bz2"
DEPS="rime-deps-${LIBRIME_COMMIT}-macOS-universal.tar.bz2"
STATIC_PACK="librime-static.xcframework.zip"
STATIC_BASE="https://github.com/ghostflyby/librime-xcframework/releases/download/${RIME_PACK_TAG}"
CACHE="$VENDOR/.cache"
OUT="$VENDOR/librime"
XCF="$ROOT/Packages/HufuKit/Frameworks/CRime.xcframework"
STAMP="$LIBRIME_COMMIT-$RIME_PACK_TAG"

download() {
  local url="$1" file="$2"
  [[ -f "$CACHE/$file" ]] && return
  echo "==> downloading $file"
  curl -fL --retry 3 -o "$CACHE/$file.part" "$url"
  mv "$CACHE/$file.part" "$CACHE/$file"
}

mkdir -p "$CACHE"
download "$BASE/$ENGINE" "$ENGINE"
download "$BASE/$DEPS" "$DEPS"
download "$STATIC_BASE/$STATIC_PACK" "$STATIC_PACK"

echo "==> verifying sha256"
(cd "$CACHE" && grep -E '^[0-9a-f]{64}  ' "$LOCK" | shasum -a 256 -c -)

if [[ -f "$OUT/.stamp" && "$(cat "$OUT/.stamp")" == "$STAMP" && -d "$XCF" \
      && -d "$OUT/static/librime-static.xcframework" ]]; then
  rm -rf "$OUT/lib/rime-plugins" "$OUT/static/librime-static.xcframework"/ios-*
  echo "==> librime $LIBRIME_VERSION ($LIBRIME_COMMIT, $RIME_PACK_TAG) already assembled"
  exit 0
fi

echo "==> extracting"
rm -rf "$OUT" "$XCF" "$VENDOR/.stage"
STAGE="$VENDOR/.stage"
mkdir -p "$STAGE" "$OUT/lib" "$OUT/share" "$OUT/static"
tar -xjf "$CACHE/$ENGINE" -C "$STAGE"
tar -xjf "$CACHE/$DEPS" -C "$STAGE"
ditto -x -k "$CACHE/$STATIC_PACK" "$OUT/static"
rm -rf "$OUT/static/librime-static.xcframework"/ios-*

# The dynamic engine is only an input for the staging tools.
cp -L "$STAGE/dist/lib/librime.1.dylib" "$OUT/lib/"
cp -RL "$STAGE/share/opencc" "$OUT/share/opencc"
cp -R "$STAGE/dist/bin" "$OUT/bin"
cp "$STAGE/version-info.txt" "$OUT/version-info.txt"

STATIC_XCF="$OUT/static/librime-static.xcframework"
STATIC_SLICE="$STATIC_XCF/macos-arm64_x86_64"
[[ -f "$STATIC_SLICE/librime.a" ]] || { echo "missing macOS static archive" >&2; exit 1; }

# Headers + module map for Swift (module CRime).
HDR="$STAGE/headers"
mkdir -p "$HDR"
cp "$STATIC_SLICE/Headers/rime_api.h" "$STATIC_SLICE/Headers/rime_api_stdbool.h" \
   "$STATIC_SLICE/Headers/rime_levers_api.h" "$HDR/"
cat > "$HDR/CRime.h" <<'H'
#include "rime_api_stdbool.h"
#include "rime_api.h"
#include "rime_levers_api.h"
H
cat > "$HDR/module.modulemap" <<'M'
module CRime {
  umbrella header "CRime.h"
  export *
}
M

echo "==> building static CRime.xcframework"
xcodebuild -create-xcframework \
  -library "$STATIC_SLICE/librime.a" -headers "$HDR" \
  -output "$XCF" >/dev/null

rm -rf "$STAGE"
echo "$STAMP" > "$OUT/.stamp"
echo "==> done: $XCF"
