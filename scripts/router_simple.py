#!/usr/bin/env python3
"""
KLAWAQUA-AGI: Router Automático Local↔Cloud (Simplificado)
Fallback instantáneo sin esperas
"""

import requests
import time
import os

OLLAMA_BASE = "http://localhost:11434"
OPENROUTER_KEY = os.getenv('OPENROUTER_API_KEY', '')
OPENROUTER_BASE = "https://openrouter.ai/api/v1"

# Modelos en orden de prioridad
LOCAL_MODELS = ["qwen3.5:4b", "mistral:7b", "qwen3:4b"]
CLOUD_MODELS = [
    "nvidia/nemotron-3-super-120b-a12b:free",
    "poolside/laguna-m.1:free",
    "inclusionai/ling-2.6-1t:free"
]

def check_local(model):
    """Verificar modelo local rápido"""
    try:
        r = requests.post(f"{OLLAMA_BASE}/api/generate", 
                         json={"model": model, "prompt": "OK", "stream": False},
                         timeout=3)
        return r.status_code == 200
    except:
        return False

def generate_local(model, prompt):
    """Generar con modelo local"""
    try:
        r = requests.post(f"{OLLAMA_BASE}/api/generate",
                         json={"model": model, "prompt": prompt, "stream": False},
                         timeout=60)
        return r.json().get('response', '')
    except Exception as e:
        return f"Error local: {e}"

def generate_cloud(model, prompt):
    """Generar con cloud OpenRouter"""
    try:
        headers = {"Authorization": f"Bearer {OPENROUTER_KEY}"}
        r = requests.post(f"{OPENROUTER_BASE}/chat/completions",
                         headers=headers,
                         json={"model": model, "messages": [{"role": "user", "content": prompt}], "max_tokens": 500},
                         timeout=60)
        return r.json()['choices'][0]['message']['content']
    except Exception as e:
        return f"Error cloud: {e}"

def auto_generate(prompt):
    """
    Generar con auto fallback local→cloud
    Prioridad: local primero, si falla → cloud free
    """
    print(f"🔄 Router: Procesando...")
    
    # Intentar locales primero
    for model in LOCAL_MODELS:
        if check_local(model):
            print(f"✅ Usando LOCAL: {model}")
            start = time.time()
            response = generate_local(model, prompt)
            latency = int((time.time() - start) * 1000)
            return response, model, 'local', latency
    
    print("⚠️ Local no disponible, fallback a CLOUD...")
    
    # Fallback a cloud
    for model in CLOUD_MODELS:
        print(f"☁️ Intentando CLOUD: {model}")
        start = time.time()
        response = generate_cloud(model, prompt)
        latency = int((time.time() - start) * 1000)
        if not response.startswith("Error"):
            return response, model, 'cloud', latency
    
    return "❌ Todos los modelos fallaron", "none", "error", 0

if __name__ == "__main__":
    import sys
    prompt = sys.argv[1] if len(sys.argv) > 1 else "Di hola"
    
    print("=" * 60)
    print("KLAWAQUA-AGI: Router Automático Test")
    print("=" * 60)
    
    response, model, source, latency = auto_generate(prompt)
    
    print(f"\n📝 Respuesta:")
    print(response[:200])
    print(f"\n📊 Estadísticas:")
    print(f"  Modelo: {model}")
    print(f"  Fuente: {source}")
    print(f"  Latencia: {latency}ms")
    print("=" * 60)
