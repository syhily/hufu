#!/usr/bin/env python3
"""Build the client-side Tiger-Code lookup index from the bundled dictionaries.

Reads dicts/huma/tigress.dict.yaml (characters) and
dicts/huma/tigress_words_simp.dict.yaml (simplified words), writes
site/public/dict/index.json:

    {"version": "...",
     "chars": ["<char>|<full code>|<short code> <short code> ...", ...],
     "words": ["<word>|<full code> <short code> ...", ...]}

The first code in a character entry is its full code, the rest are short
codes. Packing each record into one string keeps the payload at ~3.2 MiB
instead of ~5.2 MiB for nested arrays; the field names and code order still
carry the type. Entries are sorted by text so repeated runs are byte-identical.
"""
from __future__ import annotations

import json
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DICT_DIR = ROOT / 'dicts/huma'
OUT = ROOT / 'site/public/dict/index.json'

CHAR_DICT = DICT_DIR / 'tigress.dict.yaml'
WORD_DICT = DICT_DIR / 'tigress_words_simp.dict.yaml'

# Upstream Tiger-Code release the bundled tables are derived from (see
# scripts/stage-huma.sh and dicts/huma/README.md); the yaml `version:` is the
# local rebuild date, not the release.
SOURCE_VERSION = '2026.08.15'


def parse(path: Path):
    """Return (text, code) pairs from the dictionary body after the `...` marker."""
    rows = []
    in_body = False
    for line in path.read_text(encoding='utf-8').splitlines():
        if not in_body:
            if line.strip() == '...':
                in_body = True
            continue
        if not line.strip() or line.startswith('#'):
            continue
        cols = line.split('\t')
        if len(cols) < 3:
            continue
        rows.append((cols[0], cols[2]))
    return rows


def char_records(rows):
    """Full code = first longest code in file order; the rest are short codes."""
    grouped = defaultdict(list)
    for text, code in rows:
        grouped[text].append(code)

    records = []
    for text in sorted(grouped):
        codes = grouped[text]
        longest = max(len(code) for code in codes)
        full = next(code for code in codes if len(code) == longest)
        shorts = sorted(code for code in codes if code != full)
        records.append(f'{text}|{full}|{" ".join(shorts)}' if shorts else f'{text}|{full}')
    return records


def word_records(rows):
    grouped = defaultdict(list)
    for text, code in rows:
        grouped[text].append(code)

    records = []
    for text in sorted(grouped):
        codes = sorted(set(grouped[text]), key=lambda code: (-len(code), code))
        records.append(f'{text}|{" ".join(codes)}')
    return records


def main():
    char_rows = parse(CHAR_DICT)
    word_rows = parse(WORD_DICT)

    chars = char_records(char_rows)
    words = word_records(word_rows)

    payload = {'version': SOURCE_VERSION, 'chars': chars, 'words': words}
    data = json.dumps(payload, ensure_ascii=False, separators=(',', ':')).encode('utf-8')

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(data)

    print(f'version {SOURCE_VERSION}')
    print(f'chars {len(char_rows)} codes / {len(chars)} characters')
    print(f'words {len(word_rows)} codes / {len(words)} words')
    print(f'wrote {OUT.relative_to(ROOT)}: {len(data)} bytes ({len(data) / 1024 / 1024:.2f} MiB)')
    if len(data) > 4 * 1024 * 1024:
        print('warning: index exceeds 4 MiB', file=sys.stderr)


if __name__ == '__main__':
    main()
