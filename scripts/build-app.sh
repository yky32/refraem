#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
swift build -c release

BIN="$ROOT/.build/release/Refraem"
if [[ ! -f "$BIN" ]]; then
  BIN="$ROOT/.build/out/Release/Refraem"
fi

BUNDLE="$ROOT/.build/out/Products/Release/Refraem_Refraem.bundle"
if [[ ! -d "$BUNDLE" ]]; then
  BUNDLE="$(find "$ROOT/.build" -path "*Release*Refraem_Refraem.bundle" -type d 2>/dev/null | head -1)"
fi
if [[ ! -d "$BUNDLE" ]]; then
  echo "error: missing Refraem_Refraem.bundle — run swift build -c release first" >&2
  exit 1
fi

VERSION="${MARKETING_VERSION:-$(tr -d '[:space:]' < "$ROOT/VERSION" 2>/dev/null || echo "0.1.0")}"
BUILD="${BUILD_NUMBER:-1}"

APP="${1:-$HOME/Applications/Refraem.app}"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Refraem"
chmod +x "$APP/Contents/MacOS/Refraem"
cp -R "$BUNDLE" "$APP/Contents/Resources/"
/usr/bin/sed \
  -e "s|REFRAEM_VERSION|${VERSION}|g" \
  -e "s|REFRAEM_BUILD|${BUILD}|g" \
  "$ROOT/scripts/Info.plist.template" > "$APP/Contents/Info.plist"

SIGN_ID="${CODE_SIGN_IDENTITY:-}"
if [[ -n "$SIGN_ID" ]]; then
  codesign --force --deep --options runtime --timestamp -s "$SIGN_ID" "$APP"
else
  codesign -s - --force --deep "$APP"
fi

echo "Built: $APP (${VERSION} build ${BUILD})"
echo "Open with: open \"$APP\""
