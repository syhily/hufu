#!/usr/bin/env python3
"""Apply Hufu's local patches to a staged copy of the Tiger-Code package.

The submodule (dicts/huma) stays pristine; this script edits the assembled
build/SharedSupport tree instead:

* tigress.schema.yaml — product name/description.
* tigress.dict.yaml   — import the product's huma_custom table.
* stroke.schema.yaml  — drop the luna_pinyin dependency and reverse-lookup
  wiring (the repository ships no luna_pinyin).

Each replacement must match exactly, so an upstream layout change fails the
build instead of silently dropping a patch. Inputs are normalised to LF.
"""

import argparse
import sys
from pathlib import Path


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        sys.exit(f"patch-huma-schema: {label}: expected exactly one match, found {count}\n---\n{old}---")
    return text.replace(old, new, 1)


def patch_tigress_schema(text):
    old = (
        "  description: |\n"
        "    虎码官方词库\n"
        "    敲 ` 鍵進入拼音反查\n"
        '  name: "虎码官方词库"\n'
    )
    new = (
        "  description: |\n"
        "    虎码（官方秃版，单字与四字及以下词组）\n"
        "    敲 ` 鍵進入拼音反查\n"
        '  name: "虎码"\n'
    )
    return replace_once(text, old, new, "tigress.schema.yaml")


def patch_tigress_dict(text):
    old = "import_tables:\n  - tigress_ci\n  - tigress_simp_ci\n"
    new = old + "  - huma_custom\n"
    return replace_once(text, old, new, "tigress.dict.yaml")


def patch_stroke_schema(text):
    old = "  dependencies:\n    - luna_pinyin\n"
    text = replace_once(text, old, "", "stroke.schema.yaml dependencies")
    old = "abc_segmentor:\n  extra_tags:\n    - reverse_lookup\n\n"
    text = replace_once(text, old, "", "stroke.schema.yaml abc_segmentor")
    old = (
        "reverse_lookup:\n"
        "  dictionary: luna_pinyin\n"
        '  prefix: "`"\n'
        "  suffix: \"'\"\n"
        "  tips: 〔拼音〕\n"
        "  preedit_format:\n"
        "    - xform/([nl])v/$1ü/\n"
        "    - xform/([nl])ue/$1üe/\n"
        "    - xform/([jqxy])v/$1u/\n"
        "  comment_format:\n"
        "    - xlit/hspnz/一丨丿丶乙/\n"
        "\n"
    )
    text = replace_once(text, old, "", "stroke.schema.yaml reverse_lookup")
    old = (
        "recognizer:\n"
        "  import_preset: default\n"
        "  patterns:\n"
        '    reverse_lookup: "`[a-z]*\'?$"\n'
    )
    new = "recognizer:\n  import_preset: default\n"
    text = replace_once(text, old, new, "stroke.schema.yaml recognizer")
    return text


PATCHES = {
    "tigress.schema.yaml": patch_tigress_schema,
    "tigress.dict.yaml": patch_tigress_dict,
    "stroke.schema.yaml": patch_stroke_schema,
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("shared_dir", type=Path,
                        help="staged data directory (e.g. build/SharedSupport)")
    args = parser.parse_args()
    if not args.shared_dir.is_dir():
        sys.exit(f"patch-huma-schema: not a directory: {args.shared_dir}")

    for name, patch in PATCHES.items():
        path = args.shared_dir / name
        if not path.is_file():
            sys.exit(f"patch-huma-schema: missing {path}")
        text = path.read_text(encoding="utf-8")
        text = text.replace("\r\n", "\n").replace("\r", "\n")
        with path.open("w", encoding="utf-8", newline="\n") as output:
            output.write(patch(text))
        print(f"patch-huma-schema: patched {path}")


if __name__ == "__main__":
    main()
