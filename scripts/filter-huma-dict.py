#!/usr/bin/env python3
"""Filter a Rime table dictionary to entries whose text is at most N characters.

Used to shrink the official Tiger-Code word table (tigress_ci) to the product's
single-character + short-phrase scope. Streams line by line: the YAML header
(everything through the ``...`` terminator) and comments/blank lines pass
through unchanged; entry rows whose text column exceeds --max-phrase-len
characters are dropped.
"""

import argparse
import sys
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--max-phrase-len", type=int, default=4,
                        help="keep entries whose text is at most this many characters (default: 4)")
    args = parser.parse_args()

    kept = dropped = 0
    in_body = False
    lines = []
    with args.source.open("r", encoding="utf-8", newline="") as source:
        for raw in source:
            line = raw.rstrip("\r\n")
            if not in_body:
                lines.append(line)
                if line.strip() == "...":
                    in_body = True
                continue
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                lines.append(line)
                continue
            text = line.split("\t", 1)[0]
            if len(text) <= args.max_phrase_len:
                lines.append(line)
                kept += 1
            else:
                dropped += 1
    if not in_body:
        sys.exit(f"filter-huma-dict: no '...' header terminator found in {args.source}")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8", newline="\n") as output:
        for line in lines:
            output.write(line + "\n")
    print(f"filter-huma-dict: kept {kept}, dropped {dropped} (max {args.max_phrase_len} chars) -> {args.output}")


if __name__ == "__main__":
    main()
