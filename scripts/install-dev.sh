#!/usr/bin/env bash
# Builds Hufu and installs it for the current user into ~/Library/Input Methods,
# then registers and enables the input source. For a system-wide install use the
# package from scripts/package.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$HOME/Library/Input Methods"

bash "$ROOT/scripts/build-app.sh"

echo "==> installing to $DEST"
pkill -f "Input Methods/Hufu.app/Contents/MacOS/Hufu" 2>/dev/null || true
mkdir -p "$DEST"
rm -rf "$DEST/Hufu.app"
ditto "$ROOT/build/Release/Hufu.app" "$DEST/Hufu.app"
"$DEST/Hufu.app/Contents/MacOS/Hufu" --install || true
# A copy installed by the .pkg (/Library) has the same bundle id: macOS may launch
# either one and keeps showing cached icons. Development wants exactly one.
if [[ -d "/Library/Input Methods/Hufu.app" ]]; then
  echo "warning: /Library/Input Methods/Hufu.app (installed by the .pkg) also exists." >&2
  echo "         Two copies share one bundle id; remove one, e.g.:" >&2
  echo "         sudo rm -rf '/Library/Input Methods/Hufu.app' '/Applications/Hufu Settings.app'" >&2
fi
echo "==> done. If Hufu is not selectable yet, add it in System Settings › Keyboard ›"
echo "    Input Sources (log out and back in once after the first install)."
echo "    CLI: \"$DEST/Hufu.app/Contents/Helpers/hufu\" doctor"
