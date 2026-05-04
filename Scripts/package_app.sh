#!/usr/bin/env bash
# Build a runnable Sprocket.app bundle from `swift build`.
#
# Usage:
#   ./Scripts/package_app.sh            # release build
#   SPROCKET_SIGNING=adhoc ./Scripts/package_app.sh  # codesign with ad-hoc identity
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIG="${CONFIG:-release}"
APP_NAME="Sprocket"
BUNDLE_ID="nz.matt.sprocket"

swift build -c "$CONFIG" --product "$APP_NAME"
BIN="$(swift build -c "$CONFIG" --product "$APP_NAME" --show-bin-path)"

OUT="$ROOT/build/$APP_NAME.app"
rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"
cp "$BIN/$APP_NAME" "$OUT/Contents/MacOS/$APP_NAME"

cat > "$OUT/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSSupportsAutomaticTermination</key><true/>
  <key>NSSupportsSuddenTermination</key><false/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

if [[ "${SPROCKET_SIGNING:-}" == "adhoc" ]]; then
  codesign --force --deep --sign - "$OUT"
fi

echo "Built $OUT"
