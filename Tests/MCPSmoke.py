#!/usr/bin/env python3
"""Exercise the packaged stdio protocol without touching personal files."""
import json
import subprocess
import sys

process = subprocess.Popen([sys.argv[1]], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)

def call(identifier, method, params=None):
    message = {"jsonrpc": "2.0", "id": identifier, "method": method}
    if params is not None:
        message["params"] = params
    process.stdin.write(json.dumps(message) + "\n")
    process.stdin.flush()
    response = json.loads(process.stdout.readline())
    assert response["id"] == identifier, response
    return response

try:
    init = call(1, "initialize", {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "test", "version": "1"}})
    assert init["result"]["protocolVersion"] == "2025-06-18"
    process.stdin.write(json.dumps({"jsonrpc": "2.0", "method": "notifications/initialized"}) + "\n")
    process.stdin.flush()
    tools = call(2, "tools/list")["result"]["tools"]
    assert {t["name"] for t in tools} == {"scan_downloads", "scan_cleanup", "prepare_trash", "move_to_trash"}
    for tool in tools:
        assert isinstance(tool["annotations"], dict), tool
        assert isinstance(tool["inputSchema"], dict), tool
        assert tool["annotations"]["destructiveHint"] is (tool["name"] == "move_to_trash"), tool
    move = next(t for t in tools if t["name"] == "move_to_trash")
    assert set(move["inputSchema"]["required"]) == {"token", "confirmPath"}, move
    refused = call(3, "tools/call", {"name": "prepare_trash", "arguments": {"path": "/etc/passwd"}})
    assert refused["result"]["isError"] is True
    invalid = call(4, "tools/call", {"name": "move_to_trash", "arguments": {"token": "invalide"}})
    assert invalid["error"]["code"] == -32602
    partial = call(6, "tools/call", {"name": "move_to_trash", "arguments": {"token": "invalide", "confirmPath": "/tmp/x"}})
    assert partial["error"]["code"] == -32602
    assert call(5, "ping")["result"] == {}
    print("MCPSmoke OK: initialisation, schémas, outils, chemin interdit et jeton invalide")
finally:
    process.stdin.close()
    process.wait(timeout=5)
