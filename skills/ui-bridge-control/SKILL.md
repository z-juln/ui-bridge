---
name: macos-ui-control
description: Inspect and safely operate native macOS application interfaces through the local ui-bridge MCP server. Use for discovering running apps and windows, checking Accessibility or Screen Recording readiness, reading live UI state, and completing general desktop UI tasks in any Mac app when no purpose-built API or connector is available.
---

# macOS UI Control

Use the bridge as a last-mile UI tool for any macOS app. Prefer an app API, connector, or CLI when it can complete the request without driving the interface.

## Connect

Require the `ui-bridge` MCP server connected to the installed **UI Bridge.app**. Prefer the authenticated local HTTP endpoint so the independently running App owns macOS permissions and visible control state.

If the tools are absent or the connection fails:

1. Read [references/setup.md](references/setup.md) and verify that `/Applications/UI Bridge.app` is installed.
2. Launch the App through macOS Launch Services with `open -g "/Applications/UI Bridge.app"`.
3. Never recover by starting the App executable, `serve`, `start`, or `mcp` as a child process. Do not use `swift run`, `nohup`, shell `&`, a manually started stdio process, or an automatic switch to stdio.
4. Wait for `http://127.0.0.1:8765/health`, then retry MCP discovery once.
5. If the App is healthy but Cursor still shows no tools, ask the user to enable or reconnect `ui-bridge` in Cursor's MCP settings. Cursor may separately request approval before the first MCP tool call; do not mistake tool approval for App authentication.
6. Stop before UI work until the MCP tools are actually available.

Start every task with `permissions_get`. The bridge presents a native dialog with a direct System Settings button when a permission is missing. Tell the user to complete that dialog and wait for authorization. Never replace this flow with a long manual settings tutorial unless the dialog cannot open, and never claim an action happened when permission or tool support is absent.

## Work from live state

1. Call `apps_list`; match by bundle identifier and name. Return candidates instead of guessing when multiple apps match.
2. Call `windows_list` with the selected app's `pid`; prefer a visible, capturable window whose title fits the request.
3. Refresh app and window state after an app relaunch, navigation, dialog, or unexpected result.
4. Call `snapshot_get` for the selected pid and window. Use `element_find` to filter by role, text, and state; return candidates instead of choosing an ambiguous match. Request and read a screenshot when the accessibility tree is partial, the visual layout matters, or a coordinate action may be necessary.
5. Before every write, call `plan_check` with the proposed current handle or coordinate, delivery mode, and impact flags. Follow its readiness result: refresh rejected targets, capture and inspect a requested screenshot, or obtain the requested confirmation. Do not bypass the check.
6. Call `action_run` only after `plan_check` returns `ready`, using the same target and flags plus a concrete verification condition. Mark external-impact actions as `high_impact`; set `confirmed` only after the user explicitly approves the exact final action.
7. Trust success only when the returned status is `confirmed`. Continue from `new_snapshot_id`. On `not_observed`, refresh and diagnose instead of repeating the write.

## Let the bridge manage experience

- Do not ask the user to teach, save, update, approve, or delete normal operation experience.
- Do not create app-specific selector files, remembered coordinates, private memory notes, or ad hoc compatibility instructions after a successful task.
- Let UI Bridge automatically create, validate, promote, downgrade, replace, and remove experience from verified operations when that capability is available.
- Treat an experience match only as a faster candidate. A fresh snapshot, `plan_check`, `action_run`, and post-action verification remain mandatory.
- Use read-only diagnostics to explain whether experience matched or degraded. Do not expose mutating experience controls to the Agent.
- Experience never stores passwords, Cookie values, tokens, message bodies, complete screenshots, fixed coordinates, or temporary element handles, and it never bypasses high-impact confirmation.

## Protect the user

- Treat send, publish, delete, purchase, permission change, and submission as external-impact actions. Prepare them, then obtain explicit confirmation immediately before the final action.
- Do not silently bring an app to the foreground or take keyboard/mouse control. Explain why foreground control is needed and ask first.
- Prefer accessibility actions. Use `press_key` or `scroll` only when the control tree cannot express the operation. Use `coordinate_click` last, with coordinates derived from the current window snapshot; never reuse coordinates after a layout change.
- Never use remembered coordinates. Derive targets from the current window snapshot; refresh after any layout change.
- Never expose password-field values, access tokens, private message bodies, or screenshots unrelated to the task.
- On an unsupported tool or partial UI tree, report the exact limitation and the safest next step. Do not invent success.
- Call `emergency_stop` immediately if the user asks to stop, the target changes unexpectedly, or repeated UI state cannot be explained. Start a new connection before any later action.

## Diagnose

Check the App health endpoint first. If it is unavailable, follow the independent App launch flow above. Use `scripts/self_test.py` only as an explicit read-only stdio protocol diagnostic after the App connection path has been checked; never use it to recover or replace the running App.

Read [references/setup.md](references/setup.md) only for installation, client configuration, permission setup, or self-test troubleshooting.
