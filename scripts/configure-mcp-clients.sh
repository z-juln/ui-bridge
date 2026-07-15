#!/bin/zsh
set -euo pipefail

APP_EXECUTABLE="/Applications/UI Bridge.app/Contents/MacOS/ui-bridge"
ENDPOINT="http://127.0.0.1:8765/mcp"
TOKEN=$("$APP_EXECUTABLE" token)
CURSOR_MCP_CONFIG=${CURSOR_MCP_CONFIG:-"$HOME/.cursor/mcp.json"}
WORKBUDDY_MCP_CONFIG=${WORKBUDDY_MCP_CONFIG:-"$HOME/.workbuddy/mcp.json"}
OLD_CONNECTION_NAME="app-mcp-bridge"
EARLY_CONNECTION_NAME="macos-ui-bridge"

update_config() {
  local config_file=$1
  local client=$2
  local directory=${config_file:h}
  local temp
  mkdir -p "$directory"
  temp=$(mktemp "$directory/.ui-bridge.XXXXXX")

  if [[ -f "$config_file" ]]; then
    if [[ ! -f "$config_file.before-ui-bridge" ]]; then
      cp "$config_file" "$config_file.before-ui-bridge"
      chmod 600 "$config_file.before-ui-bridge"
    fi
    jq --arg endpoint "$ENDPOINT" --arg token "$TOKEN" --arg client "$client" --arg old "$OLD_CONNECTION_NAME" --arg early "$EARLY_CONNECTION_NAME" '
      .mcpServers = (.mcpServers // {}) |
      .mcpServers["ui-bridge"] = ({
        url: $endpoint,
        headers: {
          Authorization: ("Bearer " + $token),
          "X-App-MCP-Client": (if $client == "workbuddy" then "WorkBuddy" else "Cursor" end)
        }
      } + (if $client == "workbuddy" then {type: "streamable-http", timeout: 30000} else {} end)) |
      del(.mcpServers[$old], .mcpServers[$early])
    ' "$config_file" > "$temp"
  else
    jq -n --arg endpoint "$ENDPOINT" --arg token "$TOKEN" --arg client "$client" '
      {mcpServers: {"ui-bridge": ({
        url: $endpoint,
        headers: {
          Authorization: ("Bearer " + $token),
          "X-App-MCP-Client": (if $client == "workbuddy" then "WorkBuddy" else "Cursor" end)
        }
      } + (if $client == "workbuddy" then {type: "streamable-http", timeout: 30000} else {} end))}}
    ' > "$temp"
  fi

  chmod 600 "$temp"
  mv "$temp" "$config_file"
}

update_config "$CURSOR_MCP_CONFIG" cursor
update_config "$WORKBUDDY_MCP_CONFIG" workbuddy

echo "Configured ui-bridge for Cursor and WorkBuddy. Existing files were backed up beside each config."
