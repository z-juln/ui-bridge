# Setup and self-test

## Build

From the repository root, build and install the App:

```bash
./scripts/build-app.sh
./scripts/install-app.sh
python3 skills/macos-ui-control/scripts/self_test.py
```

The self-test is read-only. A successful run prints the server name, tool names, and the number of running applications.

## Cursor

Use the running App's authenticated local endpoint. Obtain its token:

```bash
/Applications/UI\ Bridge.app/Contents/MacOS/ui-bridge token
```

Configure the endpoint and replace `TOKEN_FROM_COMMAND`:

```json
{
  "mcpServers": {
    "ui-bridge": {
      "url": "http://127.0.0.1:8765/mcp",
      "headers": {
        "Authorization": "Bearer TOKEN_FROM_COMMAND",
        "X-App-MCP-Client": "Cursor"
      }
    }
  }
}
```

Do not use stdio as automatic recovery when this endpoint is temporarily unavailable. The installed App must run as an independent macOS application so it keeps the stable permission identity, menu state, live previews, and confirmation UI.

### Recover a failed connection

1. Check `http://127.0.0.1:8765/health`.
2. If unavailable, launch the installed App through Launch Services:

```bash
open -g "/Applications/UI Bridge.app"
```

3. Wait for the health endpoint, then retry or reload the configured `ui-bridge` MCP server once.
4. Never run `ui-bridge start`, `ui-bridge serve`, `ui-bridge mcp`, `swift run`, `nohup`, or a shell background process to recover the App.
5. Never silently replace the configured HTTP server with stdio.

Cursor may require two independent user approvals:

- A terminal approval if the Agent itself executes the `open` command.
- MCP tool approval before a tool call. Cursor asks by default unless the user enables auto-run or allowlists the tool/server.

Neither approval authenticates UI Bridge. With a valid local token, App startup and HTTP connection have no separate OAuth step. If the App is healthy but Cursor kept the failed server disabled, the user may need to click retry or enable once in Cursor's MCP settings.

Cursor's current MCP approval behavior is documented at <https://docs.cursor.com/context/model-context-protocol>.

### Compatibility-only stdio mode

Use stdio only when the client was deliberately configured for it and cannot use the local HTTP endpoint:

```json
{
  "mcpServers": {
    "ui-bridge": {
      "command": "/Applications/UI Bridge.app/Contents/MacOS/ui-bridge",
      "args": ["mcp"]
    }
  }
}
```

Restart or reload MCP servers, then confirm that all ten tools are visible, including `snapshot_get`, `plan_check`, `action_run`, and `emergency_stop`.

For the local Cursor and WorkBuddy installations, configure both without printing the token:

```bash
./scripts/configure-mcp-clients.sh
```

The script preserves every existing server and creates a backup beside each changed file.
WorkBuddy's own **自定义连接器 → 配置 MCP** screen reports the same file at `~/.workbuddy/mcp.json`.

## Real client write acceptance

Do not treat a visible tool list or a read-only snapshot as proof that a client can automate an app. Use a new, unsaved TextEdit document containing no user data, then run this prompt separately in Cursor and WorkBuddy:

```text
Use only ui-bridge. Run a real write test against the currently open blank TextEdit window. Call apps_list and windows_list, get a fresh snapshot, find the editable document text area, call plan_check for set_value with exact text UI_BRIDGE_CLIENT_TEST, then call action_run. Use the returned new_snapshot_id to read again and verify the document value exactly matches. Do not save or close the document and do not operate any other app. Report every tool actually called and its result.
```

Acceptance requires all of the following:

1. `plan_check` returns `ready` for the same fresh target later passed to `action_run`.
2. `action_run` returns `confirmed` and a `new_snapshot_id`.
3. A read against that new snapshot returns the exact marker text.
4. The TextEdit document visibly contains the exact marker and remains unsaved.

Use a different marker for each client. Close the test documents without saving only after recording the result. In WorkBuddy, select a workspace before sending the task; its send control stays unavailable when no workspace is selected. If another WorkBuddy task is waiting for an answer, finish or skip that question before starting this acceptance run.

## WorkBuddy and other MCP clients

Prefer the same authenticated URL when supported. Otherwise, and only as a deliberate compatibility choice, create a local stdio MCP server:

- command: `/Applications/UI Bridge.app/Contents/MacOS/ui-bridge`
- arguments: `mcp`
- working directory: the checked-out repository root when the client requests one

The client must launch one process per stdio MCP connection. Do not run the `mcp` command manually in a terminal for normal use, and never switch to this mode merely because the independent App is temporarily offline.

If WorkBuddy can read the HTTP connection but does not expose `plan_check` or `action_run`, use the installed App's safe local call entry. It reads the local credential internally, so do not put a token in a prompt, shell command, or file:

```bash
BRIDGE="/Applications/UI Bridge.app/Contents/MacOS/ui-bridge"
"$BRIDGE" call apps_list
"$BRIDGE" call windows_list '{"pid":1234}'
"$BRIDGE" call snapshot_get '{"pid":1234,"window_id":5678}'
"$BRIDGE" call element_find '{"snapshot_id":"SNAPSHOT","role":"AXTextArea","settable":true}'
"$BRIDGE" call plan_check '{"snapshot_id":"SNAPSHOT","element_handle":"HANDLE","action":"set_value"}'
"$BRIDGE" call action_run '{"snapshot_id":"SNAPSHOT","element_handle":"HANDLE","action":"set_value","text":"UI_BRIDGE_CLIENT_TEST","verification_kind":"element_value_contains","verification_value":"UI_BRIDGE_CLIENT_TEST"}'
```

For an Agent prompt, require one `call` command at a time and forbid scripts, pipes, redirects, variables, repository files, and token reads. Always use the action result's new snapshot for the final `element_find`. After a WorkBuddy test, run `git status --short`: WorkBuddy may create its own memory note even when the requested Bridge flow has finished; remove only test-created files after checking their contents.

## macOS permissions

When using the recommended local endpoint, grant Accessibility and Screen Recording only to **UI Bridge.app**. Cursor and WorkBuddy do not need those permissions. Call `permissions_get`; when access is missing, the Bridge App opens its native guidance.

Only the fallback stdio mode runs automation inside the client-launched process. In that mode, the launching client may also need macOS permissions, so prefer the local endpoint.

Call `permissions_get` to confirm the state. Discovery can work with limited permissions, but UI reading and screenshots require the corresponding grants.

## Troubleshooting

- No tools: verify that `swift build` succeeded and the configured executable path exists.
- Process exits: run the self-test and inspect its stderr output.
- Local call fails: the command prints one concise error and exits non-zero; it must not open a macOS crash dialog.
- Empty windows: confirm the app is running and retry with the current pid from `apps_list`.
- Permission remains false: open the Bridge menu, run **检查系统权限**, and restart the Bridge after changing macOS settings.
