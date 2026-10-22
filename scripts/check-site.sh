#!/usr/bin/env bash
# Serves site/ and checks every internal page, stylesheet, script and image reference.
# Portable to bash 3.2 (macOS): no associative arrays, no mapfile.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SITE="$ROOT/site"
PORT="${HUFU_SITE_PORT:-8765}"

python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$SITE" >/dev/null 2>&1 &
SERVER=$!
trap 'kill $SERVER 2>/dev/null || true' EXIT
sleep 1

failures=0
checked=0

check() {
  local path="$1"
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "http://127.0.0.1:$PORT$path" || echo 000)
  checked=$((checked + 1))
  if [ "$code" != "200" ]; then
    echo "FAIL $code $path" >&2
    failures=$((failures + 1))
  fi
}

# 24 pages: three locales × (index + seven inner pages).
for loc in "" "zh-hant/" "en/"; do
  check "/$loc"
  for page in download dictionaries themes docs changelog privacy open-source; do
    check "/$loc$page/"
  done
done

# Every internal href/src/srcset in the HTML.
python3 - "$SITE" > /tmp/hufu-site-refs.txt <<'PY'
import os, re, sys
site = sys.argv[1]
refs = set()
for root, _, files in os.walk(site):
    for name in files:
        if not name.endswith(".html"):
            continue
        text = open(os.path.join(root, name), encoding="utf-8").read()
        for match in re.finditer(r'(?:href|src)="([^"]+)"|srcset="([^"]+)"', text):
            value = match.group(1) or match.group(2)
            for part in value.split(","):
                url = part.strip().split(" ")[0]
                if not url.startswith("/") or url.startswith("//"):
                    continue
                url = url.split("#")[0].split("?")[0]
                if not url:
                    continue
                if url.endswith("/"):
                    url += "index.html"
                refs.add(url)
for ref in sorted(refs):
    print(ref)
PY

while read -r ref; do
  [ -n "$ref" ] || continue
  check "$ref"
done < /tmp/hufu-site-refs.txt

echo "checked $checked references, $failures failures"
[ "$failures" -eq 0 ]
