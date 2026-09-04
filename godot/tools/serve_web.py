#!/usr/bin/env python3
"""
Lokaler Web-Server für die Browser-Fassung (godot/build-web/).

Ein Godot-Web-Build läuft nicht per Doppelklick auf index.html (file://): Der
Browser lädt .wasm und .pck nur über HTTP. Dieses Skript liefert den Ordner aus,
setzt die richtigen MIME-Typen und die Cross-Origin-Isolation-Header (nötig,
falls später ein Build mit Thread-Unterstützung exportiert wird) und öffnet den
Browser.

    python godot/tools/serve_web.py            # Port 8060
    python godot/tools/serve_web.py 8080       # anderer Port
    python godot/tools/serve_web.py 8060 --no-browser

Im Netzwerk (Tablet am selben WLAN): http://<IP-dieses-Rechners>:8060/
"""
import http.server
import os
import socket
import socketserver
import sys
import threading
import webbrowser

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "build-web"))
if not os.path.exists(os.path.join(ROOT, "index.html")):
    # Skript liegt direkt im Build-Ordner (Kopie für die Auslieferung)
    ROOT = HERE

PORT = 8060
for a in sys.argv[1:]:
    if a.isdigit():
        PORT = int(a)
OPEN = "--no-browser" not in sys.argv


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".pck": "application/octet-stream",
        ".js": "text/javascript",
        ".html": "text/html; charset=utf-8",
    }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, fmt, *args):
        sys.stdout.write("  %s\n" % (fmt % args))


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True


def lan_ip() -> str:
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("10.255.255.255", 1))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except OSError:
        return "127.0.0.1"


if __name__ == "__main__":
    if not os.path.exists(os.path.join(ROOT, "index.html")):
        print("Kein Web-Build gefunden:", ROOT)
        print("Erst exportieren:  Godot --headless --path godot --export-release Web build-web/index.html")
        sys.exit(1)
    url = "http://localhost:%d/" % PORT
    print("Paul & REZI — Browser-Fassung")
    print("  Ordner:   ", ROOT)
    print("  Lokal:    ", url)
    print("  Netzwerk:  http://%s:%d/   (Tablet im selben WLAN)" % (lan_ip(), PORT))
    print("  Beenden:   Strg+C")
    with Server(("0.0.0.0", PORT), Handler) as httpd:
        if OPEN:
            threading.Timer(0.6, lambda: webbrowser.open(url)).start()
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            pass
