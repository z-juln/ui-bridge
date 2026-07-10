#!/usr/bin/env python3
"""Read-only end-to-end smoke test for the local MCP stdio server."""

import json
import select
import subprocess
import sys
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
BINARY = ROOT / ".build" / "debug" / "macos-ui-bridge"


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
                "clientInfo": {"name": "macos-ui-bridge-self-test", "version": "1.0"},
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
        required = {"permissions_get", "apps_list", "windows_list"}
        if server_name != "macos-ui-bridge" or not required.issubset(tool_names) or not isinstance(apps, list):
            raise RuntimeError("MCP response did not match the expected bridge contract")
        print(f"self-test passed: server={server_name} tools={','.join(tool_names)} apps={len(apps)}")
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
