#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
swift build -c release

BIN="$ROOT/.build/release/Refraem"
if [[ ! -f "$BIN" ]]; then
  BIN="$ROOT/.build/out/Release/Refraem"
fi

BUNDLE=""
for candidate in \
  "$ROOT/.build/out/Products/Release/Refraem_Refraem.bundle" \
  "$ROOT/.build/release/Refraem_Refraem.bundle" \
  "$ROOT/.build/arm64-apple-macosx/release/Refraem_Refraem.bundle"
do
  if [[ -d "$candidate" ]]; then
    BUNDLE="$candidate"
    break
  fi
done
if [[ -z "$BUNDLE" ]]; then
  BUNDLE="$(find "$ROOT/.build" -name "Refraem_Refraem.bundle" -type d 2>/dev/null | head -1)"
fi
if [[ -z "$BUNDLE" || ! -d "$BUNDLE" ]]; then
  echo "error: missing Refraem_Refraem.bundle — run swift build -c release first" >&2
  exit 1
fi

VERSION="${MARKETING_VERSION:-$(tr -d '[:space:]' < "$ROOT/VERSION" 2>/dev/null || echo "0.1.0")}"
BUILD="${BUILD_NUMBER:-1}"

APP="${1:-$HOME/Applications/Refraem.app}"
RELAUNCH=0
if [[ -z "${GITHUB_ACTIONS:-}" && "$APP" == "$HOME/Applications/Refraem.app" ]]; then
  RELAUNCH=1
  osascript -e 'tell application "Refraem" to quit' >/dev/null 2>&1 || true
  killall Refraem >/dev/null 2>&1 || true
  sleep 0.4
fi
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
swift "$ROOT/scripts/render-app-icon.swift" "$ICONSET/icon_512x512@2x.png"
sips -z 16 16 "$ICONSET/icon_512x512@2x.png" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICONSET/icon_512x512@2x.png" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICONSET/icon_512x512@2x.png" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICONSET/icon_512x512@2x.png" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICONSET/icon_512x512@2x.png" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICONSET/icon_512x512@2x.png" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICONSET/icon_512x512@2x.png" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICONSET/icon_512x512@2x.png" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICONSET/icon_512x512@2x.png" --out "$ICONSET/icon_512x512.png" >/dev/null
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
cp "$BIN" "$APP/Contents/MacOS/Refraem"
chmod +x "$APP/Contents/MacOS/Refraem"
cp -R "$BUNDLE" "$APP/Contents/Resources/"
/usr/bin/sed \
  -e "s|REFRAEM_VERSION|${VERSION}|g" \
  -e "s|REFRAEM_BUILD|${BUILD}|g" \
  "$ROOT/scripts/Info.plist.template" > "$APP/Contents/Info.plist"

SIGN_ID="${CODE_SIGN_IDENTITY:-}"
# Ad-hoc signing changes every rebuild, so macOS drops Accessibility and Screen Recording.
# A local Apple Development certificate keeps the same identity, so those toggles survive rebuilds.
if [[ -z "$SIGN_ID" && -z "${GITHUB_ACTIONS:-}" ]]; then
  SIGN_ID="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Apple Development:[^"]*\)"/\1/p' | head -1)"
fi
if [[ -n "$SIGN_ID" ]]; then
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    codesign --force --deep --options runtime --timestamp -s "$SIGN_ID" "$APP"
  else
    # No hardened runtime locally. That flag makes Accessibility stick to one build, then fail again after the next rebuild.
    codesign --force --deep -s "$SIGN_ID" "$APP"
  fi
  echo "Signed with: $SIGN_ID"
else
  codesign -s - --force --deep "$APP"
  echo "Signed ad-hoc. Privacy toggles will reset on the next rebuild."
fi

echo "Built: $APP (${VERSION} build ${BUILD})"
if [[ "$RELAUNCH" == 1 ]]; then
  open "$APP"
  echo "Reopened: $APP"
  echo "Note: after each rebuild, Screen Recording may need Refraem off→on once, then Capture again."
else
  echo "Open with: open \"$APP\""
fi
