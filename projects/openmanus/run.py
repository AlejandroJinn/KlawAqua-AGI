#!/usr/bin/env python3
"""OpenManus - KlawAqua AGI Launch Script
Arranca el servidor API con Ollama qwen3.5:4b"""
import os, sys

# Configurar PYTHONPATH
project_root = "/opt/klawaqua/projects/openmanus"
sys.path.insert(0, project_root)

# Cargar .env
env_file = os.path.join(project_root, ".env")
if os.path.exists(env_file):
    with open(env_file) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, val = line.split("=", 1)
                os.environ.setdefault(key.strip(), val.strip())

os.environ.setdefault("OPENMANUS_PORT", "8002")
os.environ.setdefault("OPENMANUS_HOST", "0.0.0.0")

import uvicorn

if __name__ == "__main__":
    port = int(os.environ["OPENMANUS_PORT"])
    host = os.environ["OPENMANUS_HOST"]
    print(f"OpenManus → {host}:{port} | Ollama → {os.environ.get('OLLAMA_BASE_URL', 'localhost:11434')} | Modelo → {os.environ.get('OPENMANUS_MODEL', 'qwen3.5:4b')}")
    uvicorn.run("src.api.main:app", host=host, port=port, reload=False)