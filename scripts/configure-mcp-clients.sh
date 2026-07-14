#!/bin/zsh
set -euo pipefail

APP_EXECUTABLE="/Applications/App MCP Bridge.app/Contents/MacOS/app-mcp-bridge"
ENDPOINT="http://127.0.0.1:8765/mcp"
TOKEN=$("$APP_EXECUTABLE" token)
CURSOR_MCP_CONFIG=${CURSOR_MCP_CONFIG:-"$HOME/.cursor/mcp.json"}
WORKBUDDY_MCP_CONFIG=${WORKBUDDY_MCP_CONFIG:-"$HOME/.workbuddy/mcp.json"}
LEGACY_CONNECTION_NAME="macos-ui-bridge"

update_config() {
  local config_file=$1
  local client=$2
  local directory=${config_file:h}
  local temp
  mkdir -p "$directory"
  temp=$(mktemp "$directory/.app-mcp-bridge.XXXXXX")

  if [[ -f "$config_file" ]]; then
    if [[ ! -f "$config_file.before-app-mcp-bridge" ]]; then
      cp "$config_file" "$config_file.before-app-mcp-bridge"
      chmod 600 "$config_file.before-app-mcp-bridge"
    fi
    jq --arg endpoint "$ENDPOINT" --arg token "$TOKEN" --arg client "$client" --arg legacy "$LEGACY_CONNECTION_NAME" '
      .mcpServers = (.mcpServers // {}) |
      .mcpServers["app-mcp-bridge"] = (
        if $client == "workbuddy" then
          {url: $endpoint, headers: {Authorization: ("Bearer " + $token), "X-App-MCP-Client": "WorkBuddy"}, type: "streamable-http", timeout: 30000}
        else
          {command: "/Applications/App MCP Bridge.app/Contents/MacOS/app-mcp-bridge", args: ["mcp"]}
        end
      ) |
      del(.mcpServers[$legacy])
    ' "$config_file" > "$temp"
  else
    jq -n --arg endpoint "$ENDPOINT" --arg token "$TOKEN" --arg client "$client" '
      {mcpServers: {"app-mcp-bridge": (
        if $client == "workbuddy" then
          {url: $endpoint, headers: {Authorization: ("Bearer " + $token), "X-App-MCP-Client": "WorkBuddy"}, type: "streamable-http", timeout: 30000}
        else
          {command: "/Applications/App MCP Bridge.app/Contents/MacOS/app-mcp-bridge", args: ["mcp"]}
        end
      )}}
    ' > "$temp"
  fi

  chmod 600 "$temp"
  mv "$temp" "$config_file"
}

update_config "$CURSOR_MCP_CONFIG" cursor
update_config "$WORKBUDDY_MCP_CONFIG" workbuddy

echo "Configured app-mcp-bridge for Cursor and WorkBuddy. Existing files were backed up beside each config."
