#!/usr/bin/env python3
"""
Servidor local para GOATcars CRM.
Sirve archivos estáticos + proxy para Notion API, OpenAI API y RapidAPI (evita CORS).
Usa ThreadingMixin para no bloquear con descargas grandes.

Uso:  python3 server.py
Abrir: http://localhost:8080
"""

import http.server
import socketserver
import json
import urllib.request
import urllib.error
import urllib.parse
import os
import sys
import base64
import threading

PORT = 8080
CRM_DIR = os.path.dirname(os.path.abspath(__file__))

PROXY_ROUTES = {
    "/api/notion/": "https://api.notion.com/",
    "/api/openai/": "https://api.openai.com/",
    "/api/rapidapi/ig/": "https://instagram-downloader-download-instagram-stories-videos4.p.rapidapi.com/",
    "/api/ideogram/": "https://api.ideogram.ai/",
}


class CRMHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=CRM_DIR, **kwargs)

    def do_POST(self):
        if self.path.startswith("/api/fetch-media"):
            self._fetch_media()
            return
        if self.path.startswith("/api/whisper-transcribe"):
            self._whisper_transcribe()
            return
        for local_prefix, remote_base in PROXY_ROUTES.items():
            if self.path.startswith(local_prefix):
                self._proxy(local_prefix, remote_base)
                return
        self.send_error(404)

    def do_GET(self):
        if self.path.startswith("/api/fetch-video"):
            self._fetch_video()
            return
        for local_prefix, remote_base in PROXY_ROUTES.items():
            if self.path.startswith(local_prefix):
                self._proxy(local_prefix, remote_base)
                return
        super().do_GET()

    def _proxy(self, local_prefix, remote_base):
        remote_path = self.path[len(local_prefix):]
        remote_url = remote_base + remote_path

        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length) if length > 0 else None

        headers = {}
        for key in ("Authorization", "Content-Type", "Notion-Version",
                     "x-rapidapi-host", "x-rapidapi-key", "Api-Key"):
            val = self.headers.get(key)
            if val:
                headers[key] = val

        try:
            req = urllib.request.Request(
                remote_url,
                data=body,
                headers=headers,
                method=self.command,
            )
            with urllib.request.urlopen(req, timeout=120) as resp:
                resp_body = resp.read()
                self.send_response(resp.status)
                self.send_header("Content-Type", resp.headers.get("Content-Type", "application/json"))
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                self.wfile.write(resp_body)
        except urllib.error.HTTPError as e:
            error_body = e.read()
            self.send_response(e.code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(error_body)
        except Exception as e:
            self._safe_error(502, str(e))

    def _fetch_video(self):
        """Stream a remote video URL through the proxy (avoids CORS)."""
        qs = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        url = qs.get("url", [""])[0]
        if not url:
            self.send_error(400, "url parameter required")
            return
        try:
            req = urllib.request.Request(url, headers={
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"
            })
            with urllib.request.urlopen(req, timeout=30) as resp:
                ct = resp.headers.get("Content-Type", "video/mp4")
                cl = resp.headers.get("Content-Length")
                self.send_response(200)
                self.send_header("Content-Type", ct)
                if cl:
                    self.send_header("Content-Length", cl)
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                while True:
                    chunk = resp.read(65536)
                    if not chunk:
                        break
                    try:
                        self.wfile.write(chunk)
                    except BrokenPipeError:
                        break
        except Exception as e:
            self._safe_error(502, str(e))

    def _fetch_media(self):
        """Download a remote media URL and return as base64 data URI."""
        length = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(length)) if length > 0 else {}
        url = body.get("url", "")
        if not url:
            self._json_response(400, {"error": "url required"})
            return
        try:
            req = urllib.request.Request(url, headers={
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"
            })
            with urllib.request.urlopen(req, timeout=30) as resp:
                media_bytes = resp.read()
                ct = resp.headers.get("Content-Type", "application/octet-stream")
                b64 = base64.b64encode(media_bytes).decode("ascii")
                self._json_response(200, {
                    "dataUri": f"data:{ct};base64,{b64}",
                    "contentType": ct,
                    "size": len(media_bytes),
                })
        except Exception as e:
            self._json_response(502, {"error": str(e)})

    def _whisper_transcribe(self):
        """Receive base64 audio, forward to OpenAI Whisper via multipart."""
        length = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(length)) if length > 0 else {}
        audio_b64 = body.get("audio_base64", "")
        api_key = body.get("api_key", "")
        if not audio_b64 or not api_key:
            self._json_response(400, {"error": "audio_base64 and api_key required"})
            return
        try:
            audio_bytes = base64.b64decode(audio_b64)
            boundary = "----CRMWhisperBoundary"
            parts = []
            parts.append(f"--{boundary}\r\nContent-Disposition: form-data; name=\"model\"\r\n\r\nwhisper-1".encode())
            parts.append(f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"audio.mp4\"\r\nContent-Type: audio/mp4\r\n\r\n".encode() + audio_bytes)
            multipart_body = b"\r\n".join(parts) + f"\r\n--{boundary}--\r\n".encode()

            req = urllib.request.Request(
                "https://api.openai.com/v1/audio/transcriptions",
                data=multipart_body,
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": f"multipart/form-data; boundary={boundary}",
                },
                method="POST",
            )
            with urllib.request.urlopen(req, timeout=120) as resp:
                result = json.loads(resp.read())
                self._json_response(200, result)
        except urllib.error.HTTPError as e:
            self._json_response(e.code, {"error": e.read().decode("utf-8", errors="replace")[:500]})
        except Exception as e:
            self._json_response(502, {"error": str(e)})

    def _json_response(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def _safe_error(self, code, msg):
        try:
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(json.dumps({"error": msg}).encode())
        except Exception:
            pass

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers",
                         "Authorization, Content-Type, Notion-Version, x-rapidapi-host, x-rapidapi-key, Api-Key")
        self.end_headers()

    def end_headers(self):
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def log_message(self, format, *args):
        path = args[0] if args else ""
        if isinstance(path, str) and path.startswith(("GET /api/", "POST /api/")):
            sys.stderr.write(f"  → {path}\n")


class ThreadedHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True


if __name__ == "__main__":
    print(f"\n  GOATcars CRM → http://localhost:{PORT}")
    print(f"  Modo: multi-thread (no bloquea con descargas)")
    print(f"  Proxy Notion   → /api/notion/...")
    print(f"  Proxy OpenAI   → /api/openai/...")
    print(f"  Proxy RapidAPI → /api/rapidapi/ig/...")
    print(f"  Proxy Ideogram → /api/ideogram/...")
    print(f"  Fetch Media    → /api/fetch-media")
    print(f"  Fetch Video    → /api/fetch-video")
    print(f"  Whisper        → /api/whisper-transcribe\n")
    with ThreadedHTTPServer(("", PORT), CRMHandler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nServidor detenido.")
