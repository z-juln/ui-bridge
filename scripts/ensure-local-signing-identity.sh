#!/bin/zsh
set -euo pipefail

STATE_DIR="$HOME/Library/Application Support/UI Bridge"
KEYCHAIN="$STATE_DIR/local-signing.keychain-db"
KEYCHAIN_PASSWORD="ui-bridge-local-development"
IDENTITY="UI Bridge Local Development"

mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"

if ! security find-identity -v -p codesigning "$KEYCHAIN" 2>/dev/null | grep -Fq "\"$IDENTITY\""; then
  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT
  rm -f "$KEYCHAIN"

  openssl req -x509 -newkey rsa:2048 -sha256 -nodes \
    -keyout "$TMP/key.pem" \
    -out "$TMP/cert.pem" \
    -days 3650 \
    -subj "/CN=$IDENTITY" \
    -addext 'keyUsage=critical,digitalSignature' \
    -addext 'extendedKeyUsage=codeSigning' >/dev/null 2>&1
  openssl pkcs12 -export \
    -inkey "$TMP/key.pem" \
    -in "$TMP/cert.pem" \
    -out "$TMP/identity.p12" \
    -passout "pass:$KEYCHAIN_PASSWORD" \
    -name "$IDENTITY"

  security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
  security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
  security import "$TMP/identity.p12" -k "$KEYCHAIN" \
    -P "$KEYCHAIN_PASSWORD" -T /usr/bin/codesign >/dev/null
  security add-trusted-cert -r trustRoot -k "$KEYCHAIN" "$TMP/cert.pem"
fi

security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
print -r -- "$KEYCHAIN"
print -r -- "$IDENTITY"
