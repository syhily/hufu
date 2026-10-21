#!/usr/bin/env bash
# Produces dist/Hufu-<version>.pkg: installs Hufu.app to /Library/Input Methods (and
# Hufu Settings.app to /Applications) and
# registers it for the installing user. Unsigned unless HUFU_INSTALLER_IDENTITY
# (a "Developer ID Installer" certificate) is set.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
VERSION="$(awk -F'"' '/MARKETING_VERSION/ {print $2; exit}' project.yml)"

[[ "${SKIP_BUILD:-0}" == 1 ]] || HUFU_REQUIRE_TIMESTAMP=$([[ "${HUFU_SIGN_IDENTITY:--}" == "-" ]] && echo 0 || echo 1) bash scripts/build-app.sh

STAGE="$ROOT/build/pkg-stage"; rm -rf "$STAGE"; mkdir -p "$STAGE"
mkdir -p "$STAGE/root/Library/Input Methods" dist
ditto --noextattr --noqtn build/Release/Hufu.app "$STAGE/root/Library/Input Methods/Hufu.app"
# Settings also goes to /Applications so it is easy to find (Launchpad, Spotlight).
mkdir -p "$STAGE/root/Applications"
ditto --noextattr --noqtn "build/Release/Hufu.app/Contents/Applications/Hufu Settings.app" "$STAGE/root/Applications/Hufu Settings.app"
# Extended attributes would be archived as ._* AppleDouble files in the payload.
xattr -cr "$STAGE/root"

# Bundles are relocatable by default: Installer would follow any other Hufu.app with the
# same bundle ID (a dev build, a copy in Downloads) and update it in place instead of
# installing to /Library/Input Methods, leaving the input method unregistered.
pkgbuild --analyze --root "$STAGE/root" "$STAGE/components.plist" >/dev/null
plutil -convert xml1 "$STAGE/components.plist"
perl -0pi -e 's#(<key>BundleIsRelocatable</key>\s*)<true/>#$1<false/>#g' "$STAGE/components.plist"
if grep -A1 BundleIsRelocatable "$STAGE/components.plist" | grep -q '<true/>'; then
  echo "error: a bundle is still relocatable" >&2; exit 1
fi
COPYFILE_DISABLE=1 pkgbuild --root "$STAGE/root" --install-location / \
  --component-plist "$STAGE/components.plist" \
  --identifier dev.yufan.hufu.inputmethod.pkg --version "$VERSION" \
  --scripts scripts/pkg/scripts "$STAGE/Hufu-component.pkg" >/dev/null

cat > "$STAGE/distribution.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
  <title>虎符输入法 Hufu $VERSION</title>
  <welcome file="welcome.html" mime-type="text/html"/>
  <license file="LICENSE"/>
  <conclusion file="conclusion.html" mime-type="text/html"/>
  <options customize="never" require-scripts="false" hostArchitectures="arm64,x86_64"/>
  <volume-check><allowed-os-versions><os-version min="15.0"/></allowed-os-versions></volume-check>
  <domains enable_localSystem="true"/>
  <choices-outline><line choice="default"><line choice="hufu"/></line></choices-outline>
  <choice id="default"/>
  <choice id="hufu" visible="false"><pkg-ref id="dev.yufan.hufu.inputmethod.pkg"/></choice>
  <pkg-ref id="dev.yufan.hufu.inputmethod.pkg" version="$VERSION" onConclusion="none">Hufu-component.pkg</pkg-ref>
</installer-gui-script>
XML
cp scripts/pkg/resources/*.html "$STAGE/"
# The installer's license page: what the package contains, then the MIT license in full.
{
  cat scripts/pkg/LICENSE-header.txt
  printf '\n\n==== MIT License (Hufu original code) ====\n\n'
  cat LICENSE
} > "$STAGE/LICENSE"

SIGN_ARGS=()
[[ -n "${HUFU_INSTALLER_IDENTITY:-}" ]] && SIGN_ARGS=(--sign "$HUFU_INSTALLER_IDENTITY")
productbuild --distribution "$STAGE/distribution.xml" --resources "$STAGE" --package-path "$STAGE" \
  ${SIGN_ARGS[@]+"${SIGN_ARGS[@]}"} "dist/Hufu-$VERSION.pkg" >/dev/null
rm -rf "$STAGE"
echo "==> dist/Hufu-$VERSION.pkg ($(du -h "dist/Hufu-$VERSION.pkg" | cut -f1))"
