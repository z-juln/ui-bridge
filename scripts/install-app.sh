#!/bin/zsh
set -euo pipefail

ROOT=${0:A:h:h}
SOURCE="$ROOT/.build/app/UI Bridge.app"
DESTINATION="/Applications/UI Bridge.app"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.juln.ui-bridge.plist"
NEW_STATE_DIR="$HOME/.ui-bridge"
NEW_SUPPORT_DIR="$HOME/Library/Application Support/ui-bridge"

OLD_RUNTIME_NAME="app-mcp-bridge"
OLD_BUNDLE_LABEL="com.juln.app-mcp-bridge"
OLD_DESTINATION="/Applications/App MCP Bridge.app"
OLD_LAUNCH_AGENT="$HOME/Library/LaunchAgents/${OLD_BUNDLE_LABEL}.plist"
OLD_STATE_DIR="$HOME/.app-mcp-bridge"
OLD_SUPPORT_DIR="$HOME/Library/Application Support/app-mcp-bridge"

EARLY_RUNTIME_NAME="macos-ui-bridge"
EARLY_BUNDLE_LABEL="com.juln.${EARLY_RUNTIME_NAME}"
EARLY_DESTINATION="/Applications/macOS UI Bridge.app"
EARLY_LAUNCH_AGENT="$HOME/Library/LaunchAgents/${EARLY_BUNDLE_LABEL}.plist"
EARLY_STATE_DIR="$HOME/.${EARLY_RUNTIME_NAME}"

"$ROOT/scripts/build-app.sh"

pkill -x ui-bridge 2>/dev/null || true
pkill -x "$OLD_RUNTIME_NAME" 2>/dev/null || true
pkill -x "$EARLY_RUNTIME_NAME" 2>/dev/null || true
launchctl bootout "gui/$UID/$OLD_BUNDLE_LABEL" 2>/dev/null || true
launchctl bootout "gui/$UID/$EARLY_BUNDLE_LABEL" 2>/dev/null || true
rm -f "$OLD_LAUNCH_AGENT" "$EARLY_LAUNCH_AGENT"
if [[ -d "$OLD_STATE_DIR" && ! -e "$NEW_STATE_DIR" ]]; then
  mv "$OLD_STATE_DIR" "$NEW_STATE_DIR"
elif [[ -d "$EARLY_STATE_DIR" && ! -e "$NEW_STATE_DIR" ]]; then
  mv "$EARLY_STATE_DIR" "$NEW_STATE_DIR"
fi
if [[ -d "$OLD_SUPPORT_DIR" && ! -e "$NEW_SUPPORT_DIR" ]]; then
  mv "$OLD_SUPPORT_DIR" "$NEW_SUPPORT_DIR"
fi
rm -rf "$DESTINATION"
cp -R "$SOURCE" "$DESTINATION"
rm -rf "$OLD_DESTINATION" "$EARLY_DESTINATION"
mkdir -p "${LAUNCH_AGENT:h}"
plutil -create xml1 "$LAUNCH_AGENT"
plutil -insert Label -string com.juln.ui-bridge "$LAUNCH_AGENT"
plutil -insert ProgramArguments -array "$LAUNCH_AGENT"
plutil -insert ProgramArguments.0 -string /usr/bin/open "$LAUNCH_AGENT"
plutil -insert ProgramArguments.1 -string -g "$LAUNCH_AGENT"
plutil -insert ProgramArguments.2 -string -a "$LAUNCH_AGENT"
plutil -insert ProgramArguments.3 -string "$DESTINATION" "$LAUNCH_AGENT"
plutil -insert RunAtLoad -bool true "$LAUNCH_AGENT"
launchctl bootout "gui/$UID/com.juln.ui-bridge" 2>/dev/null || true
launchctl bootstrap "gui/$UID" "$LAUNCH_AGENT"
launchctl kickstart -k "gui/$UID/com.juln.ui-bridge"
echo "$DESTINATION"
