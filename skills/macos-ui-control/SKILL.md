---
name: macos-ui-control
description: Inspect and safely operate native macOS application interfaces through the local macos-ui-bridge MCP server. Use for discovering running apps and windows, checking Accessibility or Screen Recording readiness, reading live UI state, and completing general desktop UI tasks in any Mac app when no purpose-built API or connector is available.
---

# macOS UI Control

Use the bridge as a last-mile UI tool for any macOS app. Prefer an app API, connector, or CLI when it can complete the request without driving the interface.

## Connect

Require the `macos-ui-bridge` MCP server. If its tools are absent, read [references/setup.md](references/setup.md), guide the user through setup, and stop before attempting UI work.

Start every task with `permissions_get`. If Accessibility is unavailable, explain which permission is missing and wait for the user to grant it. Never claim an action happened when permission or tool support is absent.

## Work from live state

1. Call `apps_list`; match by bundle identifier and name. Return candidates instead of guessing when multiple apps match.
2. Call `windows_list` with the selected app's `pid`; prefer a visible, capturable window whose title fits the request.
3. Refresh app and window state after an app relaunch, navigation, dialog, or unexpected result.
4. Use snapshot and action tools only when the connected server advertises them. This build may expose discovery tools before write tools.
5. After every write, read the UI again and verify the requested result. If verification is unclear, stop instead of repeating the write.

## Protect the user

- Treat send, publish, delete, purchase, permission change, and submission as external-impact actions. Prepare them, then obtain explicit confirmation immediately before the final action.
- Do not silently bring an app to the foreground or take keyboard/mouse control. Explain why foreground control is needed and ask first.
- Never use remembered coordinates. Derive targets from the current window snapshot; refresh after any layout change.
- Never expose password-field values, access tokens, private message bodies, or screenshots unrelated to the task.
- On an unsupported tool or partial UI tree, report the exact limitation and the safest next step. Do not invent success.

## Diagnose

Run `scripts/self_test.py` when connection behavior is uncertain. It exercises a real MCP initialization, lists tools, and calls `apps_list` without changing any app.

Read [references/setup.md](references/setup.md) only for installation, client configuration, permission setup, or self-test troubleshooting.
