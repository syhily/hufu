#!/usr/bin/env bash
# Assembles build/SharedSupport — the read-only data directory bundled into Hufu.app:
#   * 虎码官方秃版（git submodule dicts/huma → syhily/hufu-scheme，方案定制全部在上游完成）
#   * OpenCC data from the pinned librime release
#   * Hufu's own files from SharedSupport/ (default.yaml, frontend config, hufu/…)
# Fully reproducible: every input is a pinned git submodule or pinned via fetch-librime.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/dicts/huma"
OUT="$ROOT/build/SharedSupport"
HUFU_VERSION="2026.08.15"

if [[ ! -f "$SRC/tigress.dict.yaml" ]]; then
  echo "stage-huma: dicts/huma is empty; run: git submodule update --init --recursive" >&2
  exit 1
fi

[[ -d "$ROOT/Vendor/librime/share/opencc" ]] || bash "$ROOT/scripts/fetch-librime.sh"

echo "==> assembling $OUT"
rm -rf "$OUT"
mkdir -p "$OUT/opencc"

# OpenCC stock tables first; the Tiger-Code package then overlays its own
# (hu_cf/st_tu/pinyin/emoji) on top.
cp -n "$ROOT/Vendor/librime/share/opencc/"* "$OUT/opencc/" 2>/dev/null || true
# Tiger-Code package: schemas, dicts, lua/, opencc/, symbols.yaml, rime.lua,
# huma_custom.dict.yaml. Everything Hufu does not ship is excluded here, above all
# *.custom.yaml: librime treats those as patches and they would rewrite schema_list.
rsync -a \
  --exclude 'tiger.schema.yaml' \
  --exclude 'tiger.dict.yaml' \
  --exclude 'tiger.extended.dict.yaml' \
  --exclude 'tigress.extended.dict.yaml' \
  --exclude '*.custom.yaml' \
  --exclude 'README.md' \
  --exclude 'lua/dz_ci_filter.lua' \
  --exclude '.git*' \
  "$SRC/" "$OUT/"

# Hufu's own files: default.yaml, frontend config, hufu/defaults, app data.
ditto "$ROOT/SharedSupport" "$OUT"

if find "$OUT" -name '*.custom.yaml' -print -quit | grep -q .; then
  echo "stage-huma: a *.custom.yaml leaked into $OUT; refusing to continue" >&2
  exit 1
fi

echo "虎码官方秃版 ${HUFU_VERSION}" > "$OUT/hufu/VERSION"
# Diagnostic metadata for Settings, which intentionally does not link librime.
sed -n 's/^LIBRIME_VERSION=//p' "$ROOT/Vendor/librime.lock" > "$OUT/hufu/LIBRIME_VERSION"

# Prebuild librime's binary artifacts into SharedSupport/build (the traits'
# prebuilt_data_dir): first deploy on a user machine copies these instead of
# compiling every table. Later redeploys only rebuild what actually changed —
# e.g. editing huma_custom recompiles just the tigress tables (~2.5 s).
echo "==> prebuilding rime binaries into SharedSupport/build"
PREBUILD_USER="$ROOT/build/prebuild-user"
rm -rf "$PREBUILD_USER" && mkdir -p "$PREBUILD_USER"
rm -rf "$OUT/build"
DYLD_LIBRARY_PATH="$ROOT/Vendor/librime/lib" \
  "$ROOT/Vendor/librime/bin/rime_deployer" --build "$PREBUILD_USER" "$OUT" >/dev/null
mv "$PREBUILD_USER/build" "$OUT/build"
rm -rf "$PREBUILD_USER"

/usr/bin/python3 "$ROOT/scripts/dictionary-metadata.py" --shared-dir "$OUT"
bash "$ROOT/scripts/stage-plugins.sh" >/dev/null
echo "==> done: $(du -sh "$OUT" | cut -f1) in $OUT"
