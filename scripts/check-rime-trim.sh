#!/usr/bin/env bash
# Assert that a Hufu binary links only the whitelisted librime gears.
set -euo pipefail

BIN="${1:?usage: bash scripts/check-rime-trim.sh <binary>}"
[[ -f "$BIN" ]] || { echo "check-rime-trim: no such file: $BIN" >&2; exit 1; }

SYMBOLS="$(nm -C "$BIN" 2>/dev/null || true)"
[[ -n "$SYMBOLS" ]] || { echo "check-rime-trim: nm produced no symbols (stripped binary?)" >&2; exit 1; }

missing=0
for name in Simplifier TableTranslator SchemaListTranslator SwitchTranslator ShapeProcessor; do
  if ! grep -q "rime::$name" <<<"$SYMBOLS"; then
    echo "check-rime-trim: missing expected component $name" >&2
    missing=1
  fi
done

# CharsetFilter is a transitive implementation dependency of TableTranslator
# (FilterDictEntry / CharsetFilterTranslation) and cannot disappear while
# table_translator is whitelisted. It is simply not registered.
for name in ChordComposer SingleCharFilter ReverseLookupFilter; do
  if grep -q "rime::$name" <<<"$SYMBOLS"; then
    echo "check-rime-trim: forbidden component $name is linked" >&2
    missing=1
  fi
done

if grep -q "rime::CharsetFilter" <<<"$SYMBOLS"; then
  echo "check-rime-trim: note: CharsetFilter is linked via TableTranslator (not registered)" >&2
fi

[[ "$missing" == 0 ]] || exit 1
echo "check-rime-trim: OK ($BIN)"
