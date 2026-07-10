# Setup and self-test

## Build

From the repository root:

```bash
swift build
python3 skills/macos-ui-control/scripts/self_test.py
```

The self-test is read-only. A successful run prints the server name, tool names, and the number of running applications.

## Cursor

Add this server to the MCP configuration, replacing the project path if needed:

```json
{
  "mcpServers": {
    "macos-ui-bridge": {
      "command": "/Users/juln/Desktop/workspace/macos-ui-bridge/.build/debug/macos-ui-bridge",
      "args": ["mcp"]
    }
  }
}
```

Restart or reload MCP servers, then confirm that `permissions_get`, `apps_list`, and `windows_list` are visible.

## WorkBuddy and other MCP clients

Create a local stdio MCP server using the same command and argument shown above:

- command: `/Users/juln/Desktop/workspace/macos-ui-bridge/.build/debug/macos-ui-bridge`
- arguments: `mcp`
- working directory: `/Users/juln/Desktop/workspace/macos-ui-bridge` when the client requests one

The client must launch one process per MCP connection. Do not run the `mcp` command manually in a terminal for normal use.

## macOS permissions

Grant Accessibility and Screen Recording to the actual host process that launches the server, such as Cursor or WorkBuddy, under System Settings → Privacy & Security. Reopen that host after changing permissions.

Call `permissions_get` to confirm the state. Discovery can work with limited permissions, but UI reading and screenshots require the corresponding grants.

## Troubleshooting

- No tools: verify that `swift build` succeeded and the configured executable path exists.
- Process exits: run the self-test and inspect its stderr output.
- Empty windows: confirm the app is running and retry with the current pid from `apps_list`.
- Permission remains false: grant access to the client that launches MCP, then fully restart it.
