#!/usr/bin/env python3
"""
KlawAqua Auto-Router Service v3.0 - Service Mesh + LLM Router
Puerto 9000. Endpoints: /chat /health /models /mode /mesh/call /mesh/status
"""
import os, sys, json, time, http.server, socketserver
from datetime import datetime

sys.path.insert(0, "/opt/klawaqua/scripts")

KLAWAQUA = "/opt/klawaqua"
PORT = 9000
HOST = "0.0.0.0"

def log(msg, level="INFO"):
    ts = datetime.now().strftime("%H:%M:%S")
    line = f"[{ts}] {level}: {msg}"
    print(line, flush=True)
    try:
        os.makedirs(os.path.join(KLAWAQUA, "logs"), exist_ok=True)
        with open(os.path.join(KLAWAQUA, "logs", "router.log"), "a") as f:
            f.write(line + "\n")
    except: pass

from importlib import reload
import auto_router_v2 as router
reload(router)

# === SERVICE MESH REGISTRY ===
SERVICE_REGISTRY = {
    "agent-zero":     "http://localhost:5080",
    "openhands":      "http://localhost:3000",
    "thepopebot":     "http://localhost:8080",
    "openclaw":       "http://localhost:18789",
    "ollama":         "http://localhost:11434",
    "litellm":        "http://localhost:4000",
    "router":         "http://localhost:9000",
    "ldr":            "http://localhost:5000",
    "searxng":        "http://localhost:8081",
    "open-pomelli":   "http://localhost:3008",
    "openfang":       "http://localhost:50051",
    "openmanus":      "http://localhost:8002",
    "openswarm":      "http://localhost:8324",
}

import urllib.request, urllib.error

def mesh_call(service, path="/", method="GET", data=None, timeout=10):
    """Llama a cualquier servicio del ecosistema"""
    if service not in SERVICE_REGISTRY:
        return {"error": f"unknown service: {service}", "available": list(SERVICE_REGISTRY.keys())}
    url = f"{SERVICE_REGISTRY[service]}{path}"
    try:
        body = json.dumps(data).encode() if data else None
        req = urllib.request.Request(url, data=body, method=method)
        if data:
            req.add_header("Content-Type", "application/json")
        resp = urllib.request.urlopen(req, timeout=timeout)
        raw = resp.read()
        try:
            return {"status": resp.status, "service": service, "data": json.loads(raw)}
        except:
            return {"status": resp.status, "service": service, "data": raw.decode()[:500]}
    except urllib.error.HTTPError as e:
        return {"status": e.code, "service": service, "error": str(e)}
    except Exception as e:
        return {"status": -1, "service": service, "error": str(e)[:200]}

def mesh_status():
    """Estado de todos los servicios del mesh"""
    results = {}
    for name, url in SERVICE_REGISTRY.items():
        try:
            if name == "ollama":
                path = "/api/tags"
            elif name in ("openfang",):
                path = "/api/health"
            elif name in ("agent-zero", "litellm", "openmanus", "thepopebot"):
                path = "/health"
            elif name == "thepopebot":
                path = "/api/ping"
            else:
                path = "/"
            req = urllib.request.Request(f"{url}{path}", method="GET")
            resp = urllib.request.urlopen(req, timeout=3)
            results[name] = "online"
        except:
            results[name] = "offline"
    return results


class Handler(http.server.BaseHTTPRequestHandler):

    def do_GET(self):
        self._respond(200, self._route_get())

    def do_POST(self):
        self._respond(200, self._route_post())

    def _route_get(self):
        if self.path == "/health":
            return {
                "status": "ok", "mode": router.get_mode(),
                "local_model": router.best_local() or "offline",
                "ollama": router.ollama_up(), "port": PORT
            }
        elif self.path == "/models":
            return {"local": router.LOCAL_MODELS, "cloud_free": router.CLOUD_FREE, "mode": router.get_mode()}
        elif self.path == "/mode":
            return {"current_mode": router.get_mode()}
        elif self.path == "/mesh/status":
            return mesh_status()
        elif self.path == "/services":
            return {"services": list(SERVICE_REGISTRY.keys()), "registry": SERVICE_REGISTRY}
        else:
            return {"error": "not found"}

    def _route_post(self):
        # Parse body
        try:
            length = int(self.headers.get("Content-Length", 0))
            body = json.loads(self.rfile.read(length)) if length else {}
        except:
            return {"error": "invalid json"}

        if self.path == "/chat":
            prompt = body.get("prompt", "")
            if not prompt: return {"error": "missing prompt"}
            cid = body.get("conversation_id", "default")
            return router.route(prompt, cid)

        elif self.path == "/mode":
            mode = body.get("mode", "")
            if mode in ("local", "auto", "cloud", "paid"):
                router.set_mode(mode)
                return {"mode": mode, "changed": True}
            return {"error": "mode must be local|auto|cloud|paid"}

        elif self.path == "/mesh/call":
            service = body.get("service", "")
            path = body.get("path", "/")
            method = body.get("method", "GET")
            data = body.get("data", None)
            timeout = body.get("timeout", 15)
            if not service:
                return {"error": "missing service", "available": list(SERVICE_REGISTRY.keys())}
            return mesh_call(service, path, method, data, timeout)

        return {"error": "not found"}

    def _respond(self, code, data):
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(data, ensure_ascii=False).encode())

    def log_message(self, fmt, *args):
        pass


class ReusableTCPServer(socketserver.TCPServer):
    allow_reuse_address = True


if __name__ == "__main__":
    log(f"Router v3.0 (Mesh) starting on {HOST}:{PORT}")
    log(f"Mode: {router.get_mode()} | Local: {router.best_local() or 'not detected'}")
    log(f"Mesh: {len(SERVICE_REGISTRY)} services registered")
    with ReusableTCPServer((HOST, PORT), Handler) as srv:
        try:
            srv.serve_forever()
        except KeyboardInterrupt:
            log("Shutting down...")
            srv.shutdown()
