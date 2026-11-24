"""Send Python to the running Blender MCP add-on (null-byte framed JSON)."""

import json
import socket
import sys

HOST, PORT = "127.0.0.1", 9876


def run(code, timeout=120.0):
    with socket.create_connection((HOST, PORT), timeout=timeout) as sock:
        sock.settimeout(timeout)
        sock.sendall(
            json.dumps({"type": "execute", "code": code, "strict_json": True}).encode()
            + b"\0"
        )
        buffer = b""
        while b"\0" not in buffer:
            chunk = sock.recv(1 << 20)
            if not chunk:
                break
            buffer += chunk
    payload = buffer.split(b"\0", 1)[0]
    return json.loads(payload) if payload else {}


if __name__ == "__main__":
    print(json.dumps(run(sys.stdin.read()), indent=2)[:8000])
