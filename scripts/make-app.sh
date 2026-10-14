#!/bin/sh
# Assemble .build/Offload.app around the debug binary. PhotoKit authorization
# needs a bundle identity — a bare `swift run` binary is outside any bundle and
# PhotoKit yields an authorized-but-empty fetch on this macOS (see
# agents/progress.md). Dependency-free POSIX sh.
set -eu

cd "$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"

swift build

APP=".build/Offload.app"
BIN=".build/debug/Offload"
PLIST="Sources/Offload/Info.plist"

[ -f "$BIN" ] || { echo "make-app: no binary at $BIN — did 'swift build' succeed?" >&2; exit 1; }

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Offload"
cp "$PLIST" "$APP/Contents/Info.plist"

# Icon: build the .icns from the committed PNG family, mapped by VERIFIED
# pixel size — the filenames lie (e.g. mac256pts1x.png is really 512px, and
# several files are byte duplicates). Idempotent: the iconset is rebuilt
# each run. If sips/iconutil are missing or conversion fails, the bundle
# still assembles, just iconless — the icon is cosmetic, packaging must
# not hard-require it. There is no 16px source; icon_16x16.png is omitted.
ICONSET=".build/AppIcon.iconset"
if command -v sips >/dev/null 2>&1 && command -v iconutil >/dev/null 2>&1; then
  rm -rf "$ICONSET"
  mkdir -p "$ICONSET"
  for src in assets/mac*.png; do
    w=$(sips -g pixelWidth "$src" | sed -n 's/.*pixelWidth: //p')
    h=$(sips -g pixelHeight "$src" | sed -n 's/.*pixelHeight: //p')
    [ -n "$w" ] && [ "$w" = "$h" ] || continue
    case "$w" in
      32)   cp "$src" "$ICONSET/icon_16x16@2x.png";  cp "$src" "$ICONSET/icon_32x32.png" ;;
      64)   cp "$src" "$ICONSET/icon_32x32@2x.png" ;;
      128)  cp "$src" "$ICONSET/icon_128x128.png" ;;
      256)  cp "$src" "$ICONSET/icon_128x128@2x.png"; cp "$src" "$ICONSET/icon_256x256.png" ;;
      512)  cp "$src" "$ICONSET/icon_256x256@2x.png"; cp "$src" "$ICONSET/icon_512x512.png" ;;
      1024) cp "$src" "$ICONSET/icon_512x512@2x.png" ;;
      *)    : ;; # no iconset slot (e.g. the 2048px source)
    esac
  done
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns" \
    || echo "make-app: icon conversion failed — assembling iconless" >&2
fi

# Stamp the build identity so the in-app footer always answers "which
# build is this?" (WizardShell.buildInfo reads these keys). Stamped ONLY
# into the bundle here - the sources Info.plist never carries release
# metadata, so it needs no bump coordination.
COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo nobuildinfo)
PLIST="$APP/Contents/Info.plist"
plutil -replace OffloadCommitHash -string "$COMMIT" "$PLIST"
plutil -replace CFBundleShortVersionString -string "0.1.1" "$PLIST"
plutil -replace CFBundleVersion -string "1" "$PLIST"

echo "make-app: bundle ready at $APP (build: $COMMIT)"
echo "make-app: run with:"
echo "  OFFLOAD_ENGINE=real $APP/Contents/MacOS/Offload"
echo "make-app: (plain '$APP/Contents/MacOS/Offload' stays on the mock engine)"