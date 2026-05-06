#!/usr/bin/env bash
# Build a runnable Sprocket.app bundle from `swift build`.
#
# Usage:
#   ./Scripts/package_app.sh            # release build (signs with $APP_IDENTITY if set)
#   VERSION=0.2.0 ./Scripts/package_app.sh
#   APP_IDENTITY='Sprocket Development' ./Scripts/package_app.sh  # stable self-signed identity
#   SPROCKET_SIGNING=adhoc ./Scripts/package_app.sh  # force ad-hoc signing
#   SPROCKET_SIGNING=developer-id APP_IDENTITY='Developer ID Application: ...' ./Scripts/package_app.sh
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
swift "$ROOT/Scripts/generate_app_icon.swift" "$OUT/Contents/Resources/AppIcon.icns"

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
  <key>CFBundleIconFile</key><string>AppIcon</string>
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

case "${SPROCKET_SIGNING:-}" in
  adhoc)
    codesign --force --deep --sign - "$OUT"
    ;;
  developer-id)
    if [[ -z "${APP_IDENTITY:-}" ]]; then
      echo "APP_IDENTITY is required when SPROCKET_SIGNING=developer-id" >&2
      exit 1
    fi

    echo "Signing with Developer ID identity: $APP_IDENTITY"
    codesign --force --deep --sign "$APP_IDENTITY" --options runtime --timestamp "$OUT"
    ;;
  "")
    if [[ -n "${APP_IDENTITY:-}" ]]; then
      echo "Signing with identity: $APP_IDENTITY"
      codesign --force --deep --sign "$APP_IDENTITY" --options runtime --timestamp=none "$OUT"
    fi
    ;;
  *)
    echo "Unknown SPROCKET_SIGNING value: $SPROCKET_SIGNING" >&2
    exit 1
    ;;
esac

echo "Built $OUT"
