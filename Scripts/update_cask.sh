#!/usr/bin/env bash
# Update the Homebrew cask after a GitHub release artifact exists.
#
# Usage:
#   ./Scripts/update_cask.sh 0.2.0 build/Sprocket-0.2.0-macos.zip
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:?version is required, e.g. 0.2.0}"
ARTIFACT="${2:?release zip path is required}"
CASK="$ROOT/Casks/sprocket.rb"

SHA256="$(shasum -a 256 "$ARTIFACT" | awk '{print $1}')"

perl -0pi -e "s/version \"[^\"]+\"/version \"$VERSION\"/" "$CASK"
perl -0pi -e "s/sha256 \"[^\"]+\"/sha256 \"$SHA256\"/" "$CASK"

echo "Updated $CASK to $VERSION ($SHA256)"
