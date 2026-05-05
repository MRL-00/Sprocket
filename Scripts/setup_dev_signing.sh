#!/usr/bin/env bash
# Generate a stable self-signed code-signing certificate so rebuilds keep the
# same signing identity, which keeps macOS Keychain ACLs valid across builds
# (no more "always allow" prompts after every rebuild).
#
# Adapted from CodexBar's setup_dev_signing.sh.
set -euo pipefail

CERT_NAME="Sprocket Development"

if security find-certificate -c "$CERT_NAME" >/dev/null 2>&1; then
    echo "✅ Certificate '$CERT_NAME' already exists."
    echo ""
    echo "Add this to ~/.zshrc (or your shell profile):"
    echo "    export APP_IDENTITY='$CERT_NAME'"
    exit 0
fi

echo "Creating self-signed certificate '$CERT_NAME'..."

TEMP_CONFIG=$(mktemp)
trap "rm -f $TEMP_CONFIG" EXIT

cat > "$TEMP_CONFIG" <<EOF
[ req ]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[ req_distinguished_name ]
CN = $CERT_NAME
O = Sprocket Development
C = US

[ v3_req ]
keyUsage = critical,digitalSignature
extendedKeyUsage = codeSigning
EOF

openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 \
    -nodes -keyout /tmp/sprocket-dev.key -out /tmp/sprocket-dev.crt \
    -config "$TEMP_CONFIG" 2>/dev/null

openssl pkcs12 -export -out /tmp/sprocket-dev.p12 \
    -inkey /tmp/sprocket-dev.key -in /tmp/sprocket-dev.crt \
    -passout pass: 2>/dev/null

security import /tmp/sprocket-dev.p12 \
    -k ~/Library/Keychains/login.keychain-db \
    -T /usr/bin/codesign -T /usr/bin/security

rm -f /tmp/sprocket-dev.{key,crt,p12}

cat <<EOF

✅ Certificate created.

⚠️  Trust it for code signing:
1. Open Keychain Access.app
2. Find '$CERT_NAME' in the 'login' keychain
3. Double-click it → expand 'Trust' → set 'Code Signing' to 'Always Trust'
4. Close the window (enter your password when prompted)

Then add this to your shell profile (~/.zshrc):
    export APP_IDENTITY='$CERT_NAME'

Restart your terminal and rebuild with:
    ./Scripts/package_app.sh && open build/Sprocket.app

The first launch after this still prompts once; click "Always Allow" — and you
won't be prompted again across future rebuilds.
EOF
