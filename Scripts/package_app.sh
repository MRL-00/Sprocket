#!/usr/bin/env bash
# Build a runnable Sprocket.app bundle from `swift build`.
#
# Usage:
#   ./Scripts/package_app.sh            # release build (signs with $APP_IDENTITY if set)
#   VERSION=0.2.0 ./Scripts/package_app.sh
#   APP_IDENTITY='Sprocket Development' ./Scripts/package_app.sh  # stable self-signed identity
#   SPROCKET_SIGNING=adhoc ./Scripts/package_app.sh  # force ad-hoc signing
#
# A stable signing identity keeps Keychain ACLs valid across rebuilds, so the
# user isn't prompted to allow Keychain access every time. Run
# Scripts/setup_dev_signing.sh once to create the cert.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIG="${CONFIG:-release}"
APP_NAME="Sprocket"
BUNDLE_ID="nz.matt.sprocket"
VERSION="${VERSION:-0.1}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"

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
  <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
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
elif [[ -n "${APP_IDENTITY:-}" ]]; then
  echo "Signing with identity: $APP_IDENTITY"
  codesign --force --deep --sign "$APP_IDENTITY" --options runtime --timestamp=none "$OUT"
fi

echo "Built $OUT"
