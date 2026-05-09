#!/usr/bin/env python3
"""
Puente ThePopeBot → Open Pomelli v1.0
Permite que ThePopeBot orqueste tareas de Open Pomelli:
- brand_extract: extraer marca de URL
- campaign_create: generar campana de marketing
- photo_studio: fotografia de producto
- animate: animar imagen a video
- asset_create: generar creativo para plataforma

Corre bajo demanda, no en background.
"""

import os, sys, json, time, base64, tempfile
import urllib.request
import urllib.error
from pathlib import Path

POMELLI_URL = "http://localhost:3006"
MUAPI_BASE = "https://api.muapi.ai/api/v1"
MUAPI_KEY = "b90bdfe48e09e8adaafa02d41b7506be2f9c724ed41abdf3a566eee34054cd7c"


def _req(method, path, headers=None, data=None, timeout=120):
    """Petición HTTP genérica"""
    url = f"{POMELLI_URL}{path}" if path.startswith("/") else path
    h = {"Content-Type": "application/json"}
    if headers: h.update(headers)
    
    body = json.dumps(data).encode() if data else None
    req = urllib.request.Request(url, data=body, headers=h, method=method)
    
    resp = urllib.request.urlopen(req, timeout=timeout)
    return json.loads(resp.read())


def _req_form(path, files=None, fields=None, timeout=120):
    """Petición con multipart/form-data"""
    import re
    boundary = "----WebKitFormBoundary" + os.urandom(8).hex()
    body = b""
    
    if fields:
        for key, val in fields.items():
            body += f"--{boundary}\r\nContent-Disposition: form-data; name=\"{key}\"\r\n\r\n{val}\r\n".encode()
    
    if files:
        for key, val in files.items():
            body += f"--{boundary}\r\nContent-Disposition: form-data; name=\"{key}\"; filename=\"{val['name']}\"\r\n".encode()
            body += f"Content-Type: {val.get('type', 'application/octet-stream')}\r\n\r\n".encode()
            body += val['data'] + b"\r\n"
    
    body += f"--{boundary}--\r\n".encode()
    
    h = {"Content-Type": f"multipart/form-data; boundary={boundary}"}
    req = urllib.request.Request(f"{POMELLI_URL}{path}", data=body, headers=h, method="POST")
    resp = urllib.request.urlopen(req, timeout=timeout)
    return json.loads(resp.read())


# ---- Comandos ----

def brand_extract(url):
    """Extraer Brand DNA de una URL"""
    result = _req("POST", "/api/brand/extract", data={"url": url})
    brand_id = result.get("id")
    
    # Obtener los detalles de la marca guardada
    if brand_id:
        brand = _req("GET", f"/api/brand/{brand_id}")
        return brand
    return result


def campaign_create(brand_id, goal, prompt=None):
    """Generar campana de marketing"""
    data = {
        "brandId": brand_id,
        "goal": goal,
    }
    if prompt:
        data["prompt"] = prompt
    
    result = _req("POST", "/api/campaign/create", data=data)
    return result


def asset_generate(campaign_id, concept_index=0, platform_id="instagram_feed"):
    """Generar creativo para una plataforma"""
    data = {
        "campaignId": campaign_id,
        "conceptIndex": concept_index,
        "platformId": platform_id
    }
    return _req("POST", "/api/asset/generate", data=data)


def photo_studio_generate(image_data, prompt="", style="studio_clean"):
    """Enviar foto de producto y generar fotografia profesional"""
    return _req("POST", "/api/photo-studio/generate", data={
        "imageData": image_data,
        "prompt": prompt,
        "style": style
    })


def animate_image(file_path_or_url, prompt="smooth cinematic animation", duration=5, resolution="720p"):
    """Animar imagen a video (3-12 segundos)"""
    
    # Si es archivo local, subirlo primero
    file_url = file_path_or_url
    if file_path_or_url and not file_path_or_url.startswith("http"):
        # Es path local - subir via upload API
        print(f"Subiendo imagen desde {file_path_or_url}...")
        file_path = Path(file_path_or_url)
        if not file_path.exists():
            return {"error": f"Archivo no encontrado: {file_path_or_url}"}
        
        # Leer archivo
        with open(file_path, "rb") as f:
            file_data = f.read()
        
        # Subir via MuAPI directamente
        upload_result = muapi_upload(file_data, file_path.name)
        file_url = upload_result.get("url", "")
        if not file_url:
            return {"error": "Fallo al subir la imagen a MuAPI"}
        print(f"Imagen subida: {file_url}")
    
    # Generar video
    print(f"Generando video animado ({duration}s, {resolution})...")
    result = _req("POST", "/api/animate/generate", data={
        "sourceImageUrl": file_url,
        "sourceType": "upload",
        "prompt": prompt,
        "duration": duration,
        "resolution": resolution
    })
    return result


def muapi_upload(file_data, filename, content_type="image/png"):
    """Subir archivo directamente a MuAPI"""
    import re
    boundary = "----WebKitFormBoundary" + os.urandom(8).hex()
    
    body = f"--{boundary}\r\n".encode()
    body += f"Content-Disposition: form-data; name=\"file\"; filename=\"{filename}\"\r\n".encode()
    body += f"Content-Type: {content_type}\r\n\r\n".encode()
    body += file_data + b"\r\n"
    body += f"--{boundary}--\r\n".encode()
    
    req = urllib.request.Request(
        f"{MUAPI_BASE}/upload_file",
        data=body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}", "x-api-key": MUAPI_KEY},
        method="POST"
    )
    resp = urllib.request.urlopen(req, timeout=60)
    return json.loads(resp.read())


def list_brands():
    """Listar marcas guardadas"""
    return _req("GET", "/api/brands")


def health_check():
    """Verificar que Open Pomelli esta corriendo"""
    try:
        req = urllib.request.Request(POMELLI_URL + "/", method="HEAD")
        resp = urllib.request.urlopen(req, timeout=5)
        return {"status": "running", "port": 3006}
    except:
        return {"status": "down", "port": 3006}


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "help"
    
    if cmd == "health":
        r = health_check()
        print(f"Open Pomelli: {r['status']} (port {r['port']})")
    
    elif cmd == "brand":
        if len(sys.argv) < 3:
            print("Uso: brand <url>")
        else:
            url = sys.argv[2]
            print(f"Extrayendo marca de {url}...")
            r = brand_extract(url)
            print(json.dumps(r, indent=2, ensure_ascii=False))
    
    elif cmd == "animate":
        if len(sys.argv) < 3:
            print("Uso: animate <image_path_or_url> [prompt] [duration] [resolution]")
        else:
            img = sys.argv[2]
            prompt = sys.argv[3] if len(sys.argv) > 3 else "smooth cinematic animation"
            duration = int(sys.argv[4]) if len(sys.argv) > 4 else 5
            resolution = sys.argv[5] if len(sys.argv) > 5 else "720p"
            
            print(f"Generando video desde {img}...")
            r = animate_image(img, prompt, duration, resolution)
            print(json.dumps(r, indent=2, ensure_ascii=False))
    
    else:
        print("Comandos disponibles:")
        print("  health                    - Verificar estado")
        print("  brand <url>               - Extraer marca")
        print("  animate <img> [prompt] [dur] [res] - Animar imagen")
        print("  campaign <brand_id> <goal> [prompt] - Generar campana")
        print("  asset <campaign_id> [concept] [platform] - Generar creativo")
