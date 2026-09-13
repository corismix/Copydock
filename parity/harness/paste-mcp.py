#!/usr/bin/env python3
"""Query the reference app's local MCP server with a locally cached OAuth token.

usage: paste-mcp.py tools
       paste-mcp.py call <tool-name> '<json-args>'
"""
import json
import os
import sys
import urllib.error
import urllib.request

# Override with PASTE_MCP_AUTH if the token cache lives elsewhere.
AUTH_PATH = os.path.expanduser(
    os.environ.get("PASTE_MCP_AUTH", "~/Library/Application Support/paste-mcp/tokens.json")
)
SERVER = "http://127.0.0.1:39725/mcp"


def access_token():
    with open(AUTH_PATH) as handle:
        data = json.load(handle)
    tokens = data["paste"]["tokens"]
    return tokens.get("accessToken") or tokens["access_token"]


def rpc(method, params=None, session=None, notify=False):
    body = {"jsonrpc": "2.0", "method": method}
    if not notify:
        body["id"] = 1
    if params is not None:
        body["params"] = params
    request = urllib.request.Request(
        SERVER,
        data=json.dumps(body).encode(),
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
            "Authorization": f"Bearer {access_token()}",
        },
        method="POST",
    )
    if session:
        request.add_header("Mcp-Session-Id", session)
    try:
        response = urllib.request.urlopen(request, timeout=60)
    except urllib.error.HTTPError as error:
        sys.stderr.write(f"HTTP {error.code}: {error.read()[:500]!r}\n")
        sys.exit(1)
    session_id = response.headers.get("Mcp-Session-Id")
    data = response.read().decode()
    if response.headers.get("Content-Type", "").startswith("text/event-stream"):
        payloads = []
        for block in data.replace("\r\n", "\n").split("\n\n"):
            for line in block.split("\n"):
                if line.startswith("data: "):
                    payloads.append(line[6:])
        data = payloads[-1] if payloads else ""
    return session_id, data


def main():
    command = sys.argv[1] if len(sys.argv) > 1 else "tools"
    session, _ = rpc(
        "initialize",
        {
            "protocolVersion": "2025-06-18",
            "capabilities": {},
            "clientInfo": {"name": "copydock-parity", "version": "0.1"},
        },
    )
    rpc("notifications/initialized", {}, session=session, notify=True)
    if command == "tools":
        _, data = rpc("tools/list", {}, session=session)
        print(json.dumps(json.loads(data).get("result", {}), indent=2))
    elif command == "call":
        name = sys.argv[2]
        arguments = json.loads(sys.argv[3]) if len(sys.argv) > 3 else {}
        _, data = rpc("tools/call", {"name": name, "arguments": arguments}, session=session)
        print(json.dumps(json.loads(data).get("result", {}), indent=2))
    else:
        sys.stderr.write("usage: paste-mcp.py [tools|call <name> '<json>']\n")
        sys.exit(2)


if __name__ == "__main__":
    main()
