#!/usr/bin/env bash
# Local URL opener for remote mu4e sessions on macOS/Linux clients.
# Listens only on 127.0.0.1. The SSH launcher reverse-forwards a remote
# localhost port back here, so remote Emacs can ask the local desktop session
# to open URLs quickly without a new SSH connection for every click.
set -euo pipefail

port="${1:-8765}"

exec python3 - "$port" <<'PY'
import http.server
import socketserver
import subprocess
import sys
import urllib.parse

port = int(sys.argv[1])

class ReusableTCPServer(socketserver.TCPServer):
    allow_reuse_address = True

class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != "/open":
            self.send_response(404)
            self.end_headers()
            return
        length = int(self.headers.get("Content-Length", "0") or "0")
        body = self.rfile.read(length).decode("utf-8", "replace")
        params = urllib.parse.parse_qs(body)
        url = (params.get("url") or [""])[0]
        if not (url.startswith("http://") or url.startswith("https://") or url.startswith("mailto:")):
            self.send_response(400)
            self.end_headers()
            return

        if sys.platform == "darwin":
            cmd = ["open", url]
        else:
            cmd = ["xdg-open", url]
        subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.send_response(204)
        self.end_headers()

    def log_message(self, *_args):
        pass

try:
    with ReusableTCPServer(("127.0.0.1", port), Handler) as httpd:
        httpd.serve_forever()
except OSError:
    # Already listening; assume an existing helper is running.
    sys.exit(0)
PY
