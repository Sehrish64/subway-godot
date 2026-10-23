#!/usr/bin/env python3
"""Static server for the Godot web build — correct wasm MIME + COOP/COEP headers."""
import http.server
import mimetypes

mimetypes.add_type("application/wasm", ".wasm")
mimetypes.add_type("application/javascript", ".js")
mimetypes.add_type("text/html", ".html")


import os

GZIPPED = {"/index.wasm": ("index.wasm.gz", "application/wasm")}


class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        path = self.path.split("?")[0]
        if path in GZIPPED:
            fname, ctype = GZIPPED[path]
            fpath = os.path.join(os.getcwd(), fname)
            if os.path.exists(fpath):
                data = open(fpath, "rb").read()
                self.send_response(200)
                self.send_header("Content-Type", ctype)
                self.send_header("Content-Encoding", "gzip")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
                return
        super().do_GET()

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "same-origin")
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    http.server.ThreadingHTTPServer(("127.0.0.1", 8901), Handler).serve_forever()
