import os
import sys
import gzip
import io
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

DIRECTORY = os.path.join(os.path.dirname(__file__), "build", "web")

class FastCompressedHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def end_headers(self):
        # Enable CORS and caching
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS")
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def do_GET(self):
        # If client accepts gzip and file is compressible, serve compressed on the fly
        accept_encoding = self.headers.get("Accept-Encoding", "")
        path = self.translate_path(self.path)

        if os.path.isfile(path) and "gzip" in accept_encoding:
            ext = os.path.splitext(path)[1].lower()
            if ext in [".js", ".wasm", ".html", ".css", ".json", ".map", ".ttf"]:
                try:
                    with open(path, "rb") as f:
                        data = f.read()
                    
                    # Only compress if file is larger than 1KB
                    if len(data) > 1024:
                        buf = io.BytesIO()
                        with gzip.GzipFile(fileobj=buf, mode="wb", compresslevel=6) as gz:
                            gz.write(data)
                        compressed_data = buf.getvalue()

                        self.send_response(200)
                        content_type = self.guess_type(path)
                        self.send_header("Content-Type", content_type)
                        self.send_header("Content-Encoding", "gzip")
                        self.send_header("Content-Length", str(len(compressed_data)))
                        self.end_headers()
                        self.wfile.write(compressed_data)
                        return
                except Exception:
                    pass

        return super().do_GET()

def run(port=8080):
    if not os.path.exists(DIRECTORY):
        print(f"Error: Directory '{DIRECTORY}' not found. Did you run 'flutter build web --release'?")
        sys.exit(1)

    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

    server_address = ("0.0.0.0", port)
    httpd = ThreadingHTTPServer(server_address, FastCompressedHandler)
    print(f"[Server] High-Performance Multi-threaded Gzip Server running at http://0.0.0.0:{port}/")
    print(f"[Directory] Serving: {DIRECTORY}")
    print("[Compression] Fast Gzip compression active for .js, .wasm, .html, and assets.")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped.")

if __name__ == "__main__":
    p = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    run(p)
