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

echo "make-app: bundle ready at $APP"
echo "make-app: run with:"
echo "  OFFLOAD_ENGINE=real $APP/Contents/MacOS/Offload"
echo "make-app: (plain '$APP/Contents/MacOS/Offload' stays on the mock engine)"