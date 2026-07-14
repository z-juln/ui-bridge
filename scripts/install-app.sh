#!/bin/zsh
set -euo pipefail

ROOT=${0:A:h:h}
SOURCE="$ROOT/.build/app/App MCP Bridge.app"
DESTINATION="/Applications/App MCP Bridge.app"
LEGACY_RUNTIME_NAME="macos-ui-bridge"
LEGACY_BUNDLE_LABEL="com.juln.${LEGACY_RUNTIME_NAME}"
LEGACY_DESTINATION="/Applications/macOS UI Bridge.app"
LEGACY_LAUNCH_AGENT="$HOME/Library/LaunchAgents/${LEGACY_BUNDLE_LABEL}.plist"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.juln.app-mcp-bridge.plist"
NEW_STATE_DIR="$HOME/.app-mcp-bridge"
LEGACY_STATE_DIR="$HOME/.${LEGACY_RUNTIME_NAME}"

"$ROOT/scripts/build-app.sh"

pkill -x app-mcp-bridge 2>/dev/null || true
pkill -x "$LEGACY_RUNTIME_NAME" 2>/dev/null || true
launchctl bootout "gui/$UID/$LEGACY_BUNDLE_LABEL" 2>/dev/null || true
rm -f "$LEGACY_LAUNCH_AGENT"
if [[ -d "$LEGACY_STATE_DIR" && ! -e "$NEW_STATE_DIR" ]]; then
  mv "$LEGACY_STATE_DIR" "$NEW_STATE_DIR"
fi
rm -rf "$DESTINATION"
cp -R "$SOURCE" "$DESTINATION"
rm -rf "$LEGACY_DESTINATION"
mkdir -p "${LAUNCH_AGENT:h}"
plutil -create xml1 "$LAUNCH_AGENT"
plutil -insert Label -string com.juln.app-mcp-bridge "$LAUNCH_AGENT"
plutil -insert ProgramArguments -array "$LAUNCH_AGENT"
plutil -insert ProgramArguments.0 -string /usr/bin/open "$LAUNCH_AGENT"
plutil -insert ProgramArguments.1 -string -g "$LAUNCH_AGENT"
plutil -insert ProgramArguments.2 -string -a "$LAUNCH_AGENT"
plutil -insert ProgramArguments.3 -string "$DESTINATION" "$LAUNCH_AGENT"
plutil -insert RunAtLoad -bool true "$LAUNCH_AGENT"
launchctl bootout "gui/$UID/com.juln.app-mcp-bridge" 2>/dev/null || true
launchctl bootstrap "gui/$UID" "$LAUNCH_AGENT"
launchctl kickstart -k "gui/$UID/com.juln.app-mcp-bridge"
echo "$DESTINATION"
