#!/bin/zsh
set -euo pipefail

ROOT=${0:A:h:h}
BUILD_ROOT="$ROOT/.build/app"
APP="$BUILD_ROOT/App MCP Bridge.app"

cd "$ROOT"
swift build -c release --product macos-ui-bridge
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/.build/release/macos-ui-bridge" "$APP/Contents/MacOS/macos-ui-bridge"
cp "$ROOT/Resources/App-Info.plist" "$APP/Contents/Info.plist"
swift "$ROOT/scripts/generate-app-icon.swift" "$APP/Contents/Resources/AppIcon.icns"

signing=(${(f)"$($ROOT/scripts/ensure-local-signing-identity.sh)"})
keychain=${signing[1]}
identity=${signing[2]}
original_keychains=(${(f)"$(security list-keychains -d user | sed 's/^[[:space:]]*"//; s/"$//')"})
restore_keychains() {
  security list-keychains -d user -s "${original_keychains[@]}"
}
trap restore_keychains EXIT
security list-keychains -d user -s "$keychain" "${original_keychains[@]}"
codesign --force --deep --sign "$identity" --identifier com.juln.macos-ui-bridge "$APP"
restore_keychains
trap - EXIT

plutil -lint "$APP/Contents/Info.plist"
codesign --verify --deep --strict --verbose=1 "$APP"
requirement=$(codesign -d -r- --verbose=3 "$APP" 2>&1)
[[ "$requirement" == *'Authority=macOS UI Bridge Local Development'* ]] || {
  echo "App signing requirement is not stable: $requirement" >&2
  exit 1
}
echo "$APP"
