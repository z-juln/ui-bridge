#!/usr/bin/env python3
"""Read-only end-to-end smoke test for the local MCP stdio server."""

import json
import os
import select
import subprocess
import sys
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
INSTALLED_BINARY = Path("/Applications/UI Bridge.app/Contents/MacOS/ui-bridge")
BINARY = Path(os.environ["UIBRIDGE_BINARY"]) if "UIBRIDGE_BINARY" in os.environ else (
    INSTALLED_BINARY if INSTALLED_BINARY.is_file() else ROOT / ".build" / "debug" / "ui-bridge"
)
CLIENT_NAME = os.environ.get("UIBRIDGE_CLIENT_NAME", "ui-bridge-self-test")


def main() -> int:
    if not BINARY.is_file():
        print("Bridge binary not found. Run `swift build` first.", file=sys.stderr)
        return 2

    process = subprocess.Popen(
        [str(BINARY), "mcp"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
    )
    try:
        send(process, {
            "jsonrpc": "2.0", "id": 1, "method": "initialize",
            "params": {
                "protocolVersion": "2025-06-18", "capabilities": {},
                "clientInfo": {"name": CLIENT_NAME, "version": "1.0"},
            },
        })
        initialized = receive(process, 1)
        send(process, {"jsonrpc": "2.0", "method": "notifications/initialized", "params": {}})
        send(process, {"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}})
        listed = receive(process, 2)
        send(process, {
            "jsonrpc": "2.0", "id": 3, "method": "tools/call",
            "params": {"name": "apps_list", "arguments": {}},
        })
        called = receive(process, 3)

        server_name = initialized["result"]["serverInfo"]["name"]
        tool_names = [tool["name"] for tool in listed["result"]["tools"]]
        apps = json.loads(called["result"]["content"][0]["text"])
        required = {"permissions_get", "apps_list", "windows_list", "snapshot_get", "plan_check", "action_run"}
        if server_name != "ui-bridge" or not required.issubset(tool_names) or not isinstance(apps, list):
            raise RuntimeError("MCP response did not match the expected bridge contract")

        ordered_apps = sorted(apps, key=lambda app: not app.get("isFrontmost", False))
        candidate = None
        window = None
        request_id = 4
        for app in ordered_apps:
            send(process, {
                "jsonrpc": "2.0", "id": request_id, "method": "tools/call",
                "params": {"name": "windows_list", "arguments": {"pid": app["pid"]}},
            })
            windows_result = receive(process, request_id)
            windows = json.loads(windows_result["result"]["content"][0]["text"])
            window = next((item for item in windows if item.get("isVisible") and item.get("isCapturable")), None)
            request_id += 1
            if window is not None:
                candidate = app
                break
        if candidate is None or window is None:
            raise RuntimeError("no running application has a visible capturable window")
        send(process, {
            "jsonrpc": "2.0", "id": request_id, "method": "tools/call",
            "params": {"name": "snapshot_get", "arguments": {
                "pid": candidate["pid"], "window_id": window["windowID"],
                "include_screenshot": False, "max_elements": 100, "max_depth": 8,
            }},
        })
        snapshot_result = receive(process, request_id)
        request_id += 1
        snapshot = json.loads(snapshot_result["result"]["content"][0]["text"])
        if not snapshot.get("snapshotID") or not snapshot.get("elements"):
            raise RuntimeError("snapshot_get returned no usable accessibility elements")
        target = snapshot["elements"][0]
        send(process, {
            "jsonrpc": "2.0", "id": request_id, "method": "tools/call",
            "params": {"name": "plan_check", "arguments": {
                "snapshot_id": snapshot["snapshotID"], "action": "coordinate_click",
                "coordinate_x": 1, "coordinate_y": 1,
            }},
        })
        visual_preview = json.loads(receive(process, request_id)["result"]["content"][0]["text"])
        request_id += 1
        if visual_preview.get("readiness") != "needs_screenshot":
            raise RuntimeError("plan_check allowed a coordinate action without current screenshot evidence")
        send(process, {
            "jsonrpc": "2.0", "id": request_id, "method": "tools/call",
            "params": {"name": "plan_check", "arguments": {
                "snapshot_id": snapshot["snapshotID"], "element_handle": target["handle"],
                "action": "press", "high_impact": True, "confirmed": False,
            }},
        })
        preview = json.loads(receive(process, request_id)["result"]["content"][0]["text"])
        request_id += 1
        if preview.get("readiness") != "needs_confirmation":
            raise RuntimeError("plan_check did not stop an unconfirmed high-impact action")
        send(process, {
            "jsonrpc": "2.0", "id": request_id, "method": "tools/call",
            "params": {"name": "action_run", "arguments": {
                "snapshot_id": snapshot["snapshotID"], "element_handle": target["handle"],
                "action": "press", "verification_kind": "element_present",
                "verification_value": target.get("label") or target.get("role"),
                "high_impact": True, "confirmed": False,
            }},
        })
        confirmation = json.loads(receive(process, request_id)["result"]["content"][0]["text"])
        if confirmation.get("status") != "confirmation_required":
            raise RuntimeError("high-impact action did not stop for explicit confirmation")
        print(
            f"self-test passed: server={server_name} tools={','.join(tool_names)} "
            f"apps={len(apps)} snapshot_elements={len(snapshot['elements'])} plan=checked confirmation=protected"
        )
        return 0
    except (KeyError, ValueError, RuntimeError) as error:
        print(f"self-test failed: {error}", file=sys.stderr)
        return 1
    finally:
        process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()


def send(process: subprocess.Popen, message: dict) -> None:
    assert process.stdin is not None
    process.stdin.write(json.dumps(message, separators=(",", ":")) + "\n")
    process.stdin.flush()


def receive(process: subprocess.Popen, request_id: int, timeout: float = 10) -> dict:
    assert process.stdout is not None
    deadline = time.time() + timeout
    while time.time() < deadline:
        readable, _, _ = select.select([process.stdout], [], [], 0.5)
        if readable:
            line = process.stdout.readline()
            if not line:
                break
            message = json.loads(line)
            if message.get("id") == request_id:
                return message
    stderr = ""
    if process.poll() is not None and process.stderr is not None:
        stderr = process.stderr.read().strip()
    raise RuntimeError(f"timed out waiting for response {request_id}; {stderr}")


if __name__ == "__main__":
    raise SystemExit(main())
