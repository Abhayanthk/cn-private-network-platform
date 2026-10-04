import hashlib
import json
import socket
import sys
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

BACKEND_ID = sys.argv[1] if len(sys.argv) > 1 else "A"
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 3001

# Same bytes on both backends -> same ETag, so 304s work behind the load balancer
INFO_BODY = json.dumps({
    "service": "team-app",
    "version": "1.0.0",
    "note": "This content is identical on every backend",
}).encode()
INFO_ETAG = '"' + hashlib.sha1(INFO_BODY).hexdigest()[:16] + '"'


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.route(send_body=True)

    def do_HEAD(self):
        self.route(send_body=False)

    def route(self, send_body):
        if self.path == "/":
            self.reply(200, {"message": f"Backend {BACKEND_ID} is running",
                             "host": socket.gethostname()}, send_body)
        elif self.path == "/api/status":
            self.reply(200, {"backend": BACKEND_ID, "status": "ok",
                             "time": datetime.now(timezone.utc).isoformat()},
                       send_body, {"Cache-Control": "no-store"})
        elif self.path == "/api/info":
            cache = {"Cache-Control": "public, max-age=60", "ETag": INFO_ETAG}
            if self.headers.get("If-None-Match") == INFO_ETAG:
                self.reply(304, None, False, cache)
            else:
                self.reply(200, INFO_BODY, send_body, cache)
        else:
            self.reply(404, {"error": "not found"}, send_body)

    def reply(self, status, body, send_body, extra_headers=None):
        if body is None:
            data = b""
        elif isinstance(body, bytes):
            data = body
        else:
            data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("X-Backend", BACKEND_ID)
        if status != 304:
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
        for name, value in (extra_headers or {}).items():
            self.send_header(name, value)
        self.end_headers()
        if send_body and data:
            self.wfile.write(data)


if __name__ == "__main__":
    # 0.0.0.0 = every interface, so Mac 2 can reach it over Wi-Fi
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print(f"Backend {BACKEND_ID} listening on 0.0.0.0:{PORT}", flush=True)
    server.serve_forever()
