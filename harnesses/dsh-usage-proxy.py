#!/usr/bin/env python3
"""Per-trial usage proxy for silent harnesses (dsh), run inside WSL.

Binds 127.0.0.1 on an ephemeral port, forwards every request to the upstream
API, streams SSE through unbuffered (a buffered relay reads as silence and
trips first-token deadlines), and appends one JSON line per request to the
usage log in Harpia's proxy-jsonl shape:

    {"input_tokens": N, "output_tokens": N, "cache_read_tokens": N,
     "cache_write_tokens": N, "status": 200, "path": "/chat/completions"}

DeepSeek reports usage as prompt_tokens/completion_tokens plus
prompt_cache_hit_tokens/prompt_cache_miss_tokens; input_tokens here is the
cache-miss (uncached) share, matching Perpetum's journal semantics.

Usage: dsh-usage-proxy.py --upstream https://api.deepseek.com \
           --usage-log /path/usage.jsonl --port-file /path/port.txt
"""

import argparse
import json
import socket
import ssl
import sys
import threading
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ARGS = None
LOCK = threading.Lock()


def log_usage(entry):
    with LOCK:
        with open(ARGS.usage_log, "a", encoding="utf-8") as fh:
            fh.write(json.dumps(entry) + "\n")


def normalize(usage):
    if not isinstance(usage, dict):
        return None
    prompt = usage.get("prompt_tokens") or usage.get("input_tokens") or 0
    hit = usage.get("prompt_cache_hit_tokens") or usage.get("cache_read_input_tokens") or 0
    miss = usage.get("prompt_cache_miss_tokens")
    if miss is None:
        miss = max(0, prompt - hit)
    return {
        "input_tokens": miss,
        "output_tokens": usage.get("completion_tokens") or usage.get("output_tokens") or 0,
        "cache_read_tokens": hit,
        "cache_write_tokens": usage.get("cache_creation_input_tokens") or 0,
    }


def last_usage_from_body(body: bytes, content_type: str):
    """Find usage in a JSON body or in the last SSE data: object carrying it."""
    text = body.decode("utf-8", errors="replace")
    if "text/event-stream" in content_type or text.lstrip().startswith("data:"):
        found = None
        for line in text.splitlines():
            line = line.strip()
            if not line.startswith("data:"):
                continue
            payload = line[5:].strip()
            if payload == "[DONE]":
                continue
            try:
                obj = json.loads(payload)
            except json.JSONDecodeError:
                continue
            if isinstance(obj, dict) and obj.get("usage"):
                found = obj["usage"]
        return found
    try:
        obj = json.loads(text)
    except json.JSONDecodeError:
        return None
    return obj.get("usage") if isinstance(obj, dict) else None


class Relay(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def _forward(self):
        upstream = urllib.parse.urlparse(ARGS.upstream)
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length else b""

        ctx = ssl.create_default_context()
        raw = socket.create_connection(
            (upstream.hostname, upstream.port or (443 if upstream.scheme == "https" else 80)),
            timeout=600,
        )
        conn = ctx.wrap_socket(raw, server_hostname=upstream.hostname) if upstream.scheme == "https" else raw
        try:
            path = (upstream.path.rstrip("/") + self.path) or self.path
            head = [f"{self.command} {path} HTTP/1.1", f"Host: {upstream.hostname}"]
            for key, value in self.headers.items():
                if key.lower() in ("host", "connection", "accept-encoding", "content-length"):
                    continue
                head.append(f"{key}: {value}")
            head.append("Accept-Encoding: identity")
            head.append(f"Content-Length: {len(body)}")
            head.append("Connection: close")
            conn.sendall(("\r\n".join(head) + "\r\n\r\n").encode())
            if body:
                conn.sendall(body)

            reader = conn.makefile("rb")
            status_line = reader.readline().decode("latin-1").strip()
            status = int(status_line.split(" ", 1)[1].split(" ")[0]) if " " in status_line else 502
            resp_headers = []
            content_type = ""
            upstream_chunked = False
            while True:
                line = reader.readline().decode("latin-1")
                if line in ("\r\n", "\n", ""):
                    break
                name, _, value = line.strip().partition(":")
                lname = name.lower()
                if lname == "content-type":
                    content_type = value.strip()
                if lname == "transfer-encoding" and "chunked" in value.lower():
                    upstream_chunked = True
                if lname in ("transfer-encoding", "connection", "content-length"):
                    continue
                resp_headers.append((name, value.strip()))

            self.send_response(status)
            for name, value in resp_headers:
                self.send_header(name, value)
            captured = bytearray()
            # Relay without knowing the length: read chunk-decoded? Upstream may
            # use chunked transfer; we sent Connection: close, so EOF delimits.
            # Re-chunk toward the client.
            self.send_header("Transfer-Encoding", "chunked")
            self.end_headers()
            decoder = ChunkDecoder(reader) if upstream_chunked else reader
            while True:
                piece = decoder.read(8192)
                if not piece:
                    break
                captured.extend(piece)
                self.wfile.write(f"{len(piece):X}\r\n".encode() + piece + b"\r\n")
                self.wfile.flush()
            self.wfile.write(b"0\r\n\r\n")
            self.wfile.flush()

            usage = normalize(last_usage_from_body(bytes(captured), content_type))
            entry = usage or {}
            entry.update({"status": status, "path": self.path})
            if usage is None:
                entry["note"] = "no usage in response"
            log_usage(entry)
        finally:
            conn.close()

    def do_POST(self):
        self._relay()

    def do_GET(self):
        self._relay()

    def _relay(self):
        try:
            self._forward()
        except Exception as exc:  # noqa: BLE001 — one bad request must not kill the proxy
            log_usage({"status": 502, "path": self.path, "note": f"relay error: {exc}"})
            try:
                self.send_error(502, str(exc))
            except Exception:
                pass

    def log_message(self, *_):
        pass


class ChunkDecoder:
    """Minimal HTTP/1.1 chunked-transfer decoder over a raw reader."""

    def __init__(self, reader):
        self.reader = reader
        self.remaining = 0
        self.done = False

    def read(self, _hint):
        if self.done:
            return b""
        if self.remaining == 0:
            size_line = self.reader.readline()
            if not size_line:
                self.done = True
                return b""
            try:
                self.remaining = int(size_line.strip().split(b";")[0], 16)
            except ValueError:
                self.done = True
                return b""
            if self.remaining == 0:
                self.reader.readline()
                self.done = True
                return b""
        piece = self.reader.read(min(self.remaining, 8192))
        if not piece:
            self.done = True
            return b""
        self.remaining -= len(piece)
        if self.remaining == 0:
            self.reader.readline()  # trailing CRLF
        return piece


def main():
    global ARGS
    parser = argparse.ArgumentParser()
    parser.add_argument("--upstream", required=True)
    parser.add_argument("--usage-log", required=True)
    parser.add_argument("--port-file", required=True)
    ARGS = parser.parse_args()

    server = ThreadingHTTPServer(("127.0.0.1", 0), Relay)
    with open(ARGS.port_file, "w", encoding="utf-8") as fh:
        fh.write(str(server.server_address[1]))
    print(f"usage-proxy listening on 127.0.0.1:{server.server_address[1]}", file=sys.stderr)
    server.serve_forever()


if __name__ == "__main__":
    main()
