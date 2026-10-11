#!/bin/sh
# Family beta package: dist/Offload-<version>.dmg = app bundle + first-launch
# readme. Ad-hoc signed (-s -, no Apple credentials); notarization stays
# later. Dependency-free POSIX sh, same discipline as make-app.sh.
set -eu

cd "$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"

VERSION="0.1.0" # one manual bump per release; no version plumbing yet
DMG="dist/Offload-$VERSION.dmg"
SETUP="dist/_dmg-setup"
README="docs/dmg-readme.rtf"
APP=".build/Offload.app"

sh scripts/make-app.sh

# Ad-hoc sign BEFORE the copy into the DMG staging (the copy keeps the
# identity); see agents/progress.md for the TCC/bundle-identity recipe.
# Fatal on failure — an unsigned bundle has no bundle identity for auth.
codesign --force --deep -s - "$APP"
codesign -dv "$APP" 2>&1 | grep -E 'Identifier=|Signature=' || :

[ -f "$README" ] || { echo "make-dmg: missing $README" >&2; exit 1; }

rm -rf "$SETUP"
mkdir -p "$SETUP"
cp -R "$APP" "$SETUP/Offload.app"
# Friendlier display name inside the DMG (source stays docs/dmg-readme.rtf).
cp "$README" "$SETUP/Read Me.rtf"

hdiutil create -volname Offload -srcfolder "$SETUP" -ov -format UDZO "$DMG"
hdiutil verify "$DMG"

# Probe: the DMG really contains app + readme; -nobrowse keeps Finder from
# popping a window during packaging (the coordinator's icon screenshot
# does its own attach).
MOUNT=$(hdiutil attach "$DMG" -nobrowse -readonly | awk -F'\t' 'NF>2 {print $NF}' | tail -1)
[ -n "$MOUNT" ] && [ -d "$MOUNT/Offload.app" ] || {
  echo "make-dmg: Offload.app missing inside $DMG" >&2
  hdiutil detach "$MOUNT" -force -quiet || :
  exit 1
}
[ -f "$MOUNT/Read Me.rtf" ] || {
  echo "make-dmg: readme missing inside $DMG" >&2
  hdiutil detach "$MOUNT" -force -quiet || :
  exit 1
}
hdiutil detach "$MOUNT" -quiet || echo "make-dmg: warn: busy, could not detach $MOUNT" >&2

echo "make-dmg: ready: $DMG ($(du -h "$DMG" | cut -f1))"