#!/usr/bin/env bash
# Assembles build/SharedSupport — the read-only data directory bundled into Hufu.app:
#   * 虎码官方秃版 (git submodule at dicts/huma, word table filtered to short phrases)
#   * OpenCC data from the pinned librime release
#   * Hufu's own files from SharedSupport/ (default.yaml, frontend config, huma_custom…)
# The submodule stays pristine: product tweaks are applied to the staged copy by
# scripts/patch-huma-schema.py. Fully reproducible: every input is a pinned git
# submodule or pinned via fetch-librime.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/dicts/huma"
OUT="$ROOT/build/SharedSupport"
MAX_PHRASE_LEN="${HUFU_MAX_PHRASE_LEN:-4}"
HUFU_VERSION="2026.08.15"

if [[ ! -f "$SRC/tigress.dict.yaml" ]]; then
  echo "stage-huma: dicts/huma is empty; run: git submodule update --init --recursive" >&2
  exit 1
fi

[[ -d "$ROOT/Vendor/librime/share/opencc" ]] || bash "$ROOT/scripts/fetch-librime.sh"

echo "==> filtering tigress_ci (keep text of <= $MAX_PHRASE_LEN chars)"
FILTERED="$ROOT/build/hufu/tigress_ci.dict.yaml"
/usr/bin/python3 "$ROOT/scripts/filter-huma-dict.py" --max-phrase-len "$MAX_PHRASE_LEN" \
  "$SRC/tigress_ci.dict.yaml" "$FILTERED"

echo "==> assembling $OUT"
rm -rf "$OUT"
mkdir -p "$OUT/opencc"

# OpenCC stock tables first; the Tiger-Code package then overlays its own
# (hu_cf/st_tu/pinyin/emoji) on top.
cp -n "$ROOT/Vendor/librime/share/opencc/"* "$OUT/opencc/" 2>/dev/null || true
# Tiger-Code package: schemas, dicts, lua/, opencc/, symbols.yaml, rime.lua.
# Everything Hufu does not ship is excluded here, above all *.custom.yaml: librime
# treats those as patches and they would rewrite schema_list.
# tigress_ci.dict.yaml is replaced by the filtered copy below.
rsync -a \
  --exclude 'tiger.schema.yaml' \
  --exclude 'tiger.dict.yaml' \
  --exclude 'tiger.extended.dict.yaml' \
  --exclude 'tigress.extended.dict.yaml' \
  --exclude '*.custom.yaml' \
  --exclude 'README.md' \
  --exclude 'lua/dz_ci_filter.lua' \
  --exclude '.git*' \
  --exclude 'tigress_ci.dict.yaml' \
  "$SRC/" "$OUT/"
cp "$FILTERED" "$OUT/tigress_ci.dict.yaml"

# Product tweaks live in the build output, not in the submodule.
/usr/bin/python3 "$ROOT/scripts/patch-huma-schema.py" "$OUT"

# Hufu's own files: default.yaml, frontend config, hufu/defaults, huma_custom.dict.yaml.
ditto "$ROOT/SharedSupport" "$OUT"

if find "$OUT" -name '*.custom.yaml' -print -quit | grep -q .; then
  echo "stage-huma: a *.custom.yaml leaked into $OUT; refusing to continue" >&2
  exit 1
fi

echo "虎码官方秃版 ${HUFU_VERSION}（词组 ≤ $MAX_PHRASE_LEN 字）" > "$OUT/hufu/VERSION"
# Diagnostic metadata for Settings, which intentionally does not link librime.
sed -n 's/^LIBRIME_VERSION=//p' "$ROOT/Vendor/librime.lock" > "$OUT/hufu/LIBRIME_VERSION"
/usr/bin/python3 "$ROOT/scripts/dictionary-metadata.py" --shared-dir "$OUT"
bash "$ROOT/scripts/stage-plugins.sh" >/dev/null
echo "==> done: $(du -sh "$OUT" | cut -f1) in $OUT"
