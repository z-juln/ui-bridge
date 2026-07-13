#!/bin/zsh
set -euo pipefail

APP_EXECUTABLE="/Applications/App MCP Bridge.app/Contents/MacOS/macos-ui-bridge"
ENDPOINT="http://127.0.0.1:8765/mcp"
TOKEN=$("$APP_EXECUTABLE" token)

update_config() {
  local config_file=$1
  local client=$2
  local directory=${config_file:h}
  local temp
  mkdir -p "$directory"
  temp=$(mktemp "$directory/.macos-ui-bridge.XXXXXX")

  if [[ -f "$config_file" ]]; then
    cp "$config_file" "$config_file.before-macos-ui-bridge"
    chmod 600 "$config_file.before-macos-ui-bridge"
    jq --arg endpoint "$ENDPOINT" --arg token "$TOKEN" --arg client "$client" '
      .mcpServers = (.mcpServers // {}) |
      .mcpServers["macos-ui-bridge"] = (
        if $client == "workbuddy" then
          {url: $endpoint, headers: {Authorization: ("Bearer " + $token)}, type: "streamable-http", timeout: 30000}
        else
          {command: "/Applications/App MCP Bridge.app/Contents/MacOS/macos-ui-bridge", args: ["mcp"]}
        end
      )
    ' "$config_file" > "$temp"
  else
    jq -n --arg endpoint "$ENDPOINT" --arg token "$TOKEN" --arg client "$client" '
      {mcpServers: {"macos-ui-bridge": (
        if $client == "workbuddy" then
          {url: $endpoint, headers: {Authorization: ("Bearer " + $token)}, type: "streamable-http", timeout: 30000}
        else
          {command: "/Applications/App MCP Bridge.app/Contents/MacOS/macos-ui-bridge", args: ["mcp"]}
        end
      )}}
    ' > "$temp"
  fi

  chmod 600 "$temp"
  mv "$temp" "$config_file"
}

update_config "$HOME/.cursor/mcp.json" cursor
update_config "$HOME/.workbuddy/mcp.json" workbuddy

echo "Configured macos-ui-bridge for Cursor and WorkBuddy. Existing files were backed up beside each config."
