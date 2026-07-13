#!/bin/zsh
set -euo pipefail

ROOT=${0:A:h:h}
SOURCE="$ROOT/.build/app/App MCP Bridge.app"
DESTINATION="/Applications/App MCP Bridge.app"
LEGACY_DESTINATION="/Applications/macOS UI Bridge.app"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.juln.macos-ui-bridge.plist"

"$ROOT/scripts/build-app.sh"

pkill -x macos-ui-bridge 2>/dev/null || true
rm -rf "$DESTINATION"
cp -R "$SOURCE" "$DESTINATION"
rm -rf "$LEGACY_DESTINATION"
mkdir -p "${LAUNCH_AGENT:h}"
plutil -create xml1 "$LAUNCH_AGENT"
plutil -insert Label -string com.juln.macos-ui-bridge "$LAUNCH_AGENT"
plutil -insert ProgramArguments -array "$LAUNCH_AGENT"
plutil -insert ProgramArguments.0 -string /usr/bin/open "$LAUNCH_AGENT"
plutil -insert ProgramArguments.1 -string -a "$LAUNCH_AGENT"
plutil -insert ProgramArguments.2 -string "$DESTINATION" "$LAUNCH_AGENT"
plutil -insert RunAtLoad -bool true "$LAUNCH_AGENT"
launchctl bootout "gui/$UID/com.juln.macos-ui-bridge" 2>/dev/null || true
launchctl bootstrap "gui/$UID" "$LAUNCH_AGENT"
launchctl kickstart -k "gui/$UID/com.juln.macos-ui-bridge"
echo "$DESTINATION"
