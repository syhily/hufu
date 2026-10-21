#!/usr/bin/env bash
# Finishes a release whose notarization was still in progress when CI ended
# (scripts/release.sh wrote NOTARY_PENDING.txt). Once Apple accepts every submission it
# staples the tickets into the pkg and the app inside the zip, then recomputes SHA256SUMS.
#
#   bash scripts/finish-notarization.sh <artefact-dir> [--publish]
#
# <artefact-dir> holds the CI artefact (gh run download <id> -R syhily/hufu -D <dir>).
# --publish replaces the GitHub Release assets for the same tag.
# Exit 3 while a submission is still in progress.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$(cd "${1:?usage: finish-notarization.sh <artefact-dir> [--publish]}" && pwd)"
PUBLISH="${2:-}"
[[ -f "$ROOT/.env" ]] && { set -a; . "$ROOT/.env"; set +a; }
: "${HUFU_NOTARY_KEY_PATH:?}" "${HUFU_NOTARY_KEY_ID:?}" "${HUFU_NOTARY_ISSUER_ID:?}"
[[ "$HUFU_NOTARY_KEY_PATH" = /* ]] || HUFU_NOTARY_KEY_PATH="$ROOT/$HUFU_NOTARY_KEY_PATH"
NOTARY=(--key "$HUFU_NOTARY_KEY_PATH" --key-id "$HUFU_NOTARY_KEY_ID" --issuer "$HUFU_NOTARY_ISSUER_ID")

shopt -s nullglob
PKGS=("$DIR"/Hufu-*.pkg)
[[ ${#PKGS[@]} -eq 1 ]] || { echo "expected exactly one Hufu-*.pkg in $DIR" >&2; exit 1; }
PKG="${PKGS[0]}"
VERSION="$(basename "$PKG")"
VERSION="${VERSION#Hufu-}"; VERSION="${VERSION%.pkg}"
ZIP="$DIR/Hufu-$VERSION.zip"

if [[ -f "$DIR/NOTARY_PENDING.txt" ]]; then
  while IFS=$'\t' read -r file id; do
    status="$(xcrun notarytool info "$id" "${NOTARY[@]}" --output-format json | plutil -extract status raw -o - -)"
    echo "$file ($id): $status"
    case "$status" in
      Accepted) ;;
      "In Progress") echo "still in progress, try again later"; exit 3 ;;
      *) xcrun notarytool log "$id" "${NOTARY[@]}" >&2 || true; exit 1 ;;
    esac
  done < "$DIR/NOTARY_PENDING.txt"
fi

xcrun stapler staple "$PKG" && xcrun stapler validate "$PKG"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
ditto -x -k "$ZIP" "$WORK"
xcrun stapler staple "$WORK/Hufu.app" && xcrun stapler validate "$WORK/Hufu.app"
rm -f "$ZIP" && ditto -c -k --keepParent "$WORK/Hufu.app" "$ZIP"
spctl --assess --type install --verbose=2 "$PKG"

(cd "$DIR" && shasum -a 256 "$(basename "$PKG")" "$(basename "$ZIP")" > SHA256SUMS.txt)
echo notarized > "$DIR/SIGNING_STATUS"
rm -f "$DIR/NOTARY_PENDING.txt"
cat "$DIR/SHA256SUMS.txt"

[[ "$PUBLISH" == --publish ]] || { echo "stapled; re-run with --publish to replace the release files"; exit 0; }
REPO="${GITHUB_REPOSITORY:-syhily/hufu}"
gh release upload "v$VERSION" -R "$REPO" --clobber "$PKG" "$ZIP" "$DIR/SHA256SUMS.txt"
gh release edit "v$VERSION" -R "$REPO" --title "Hufu $VERSION"
echo "published $VERSION (notarized)"
