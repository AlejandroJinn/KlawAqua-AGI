#!/usr/bin/env python3
"""
KLAWAQUA-AGI: Merlyn_bot v3 con DEBUG detallado
"""

import requests
import json

BOT_TOKEN = "8469591478:AAGjPrpL5XR7Igh0fqp-JeL6Tma8NMEDEy8"
OLLAMA_BASE = "http://localhost:11434"
MODEL = "mistral:7b"

def test_ollama(prompt="Di hola"):
    print(f"🔫 Probando Ollama con: '{prompt}'")
    url = f"{OLLAMA_BASE}/api/generate"
    data = {
        'model': MODEL,
        'prompt': prompt,
        'stream': False
    }
    
    print(f"URL: {url}")
    print(f"Data: {json.dumps(data, indent=2)}")
    print()
    
    try:
        r = requests.post(url, json=data, timeout=60)
        print(f"Status: {r.status_code}")
        print(f"Headers: {dict(r.headers)}")
        print()
        print(f"Raw Response ({len(r.text)} bytes):")
        print(r.text[:500])
        print()
        
        result = r.json()
        print(f"Parsed JSON keys: {result.keys()}")
        print(f"Full JSON: {json.dumps(result, indent=2)[:500]}")
        print()
        
        response_text = result.get('response', '---NO RESPONSE KEY---')
        print(f"✅ Response text: '{response_text[:100]}'")
        
        return response_text
        
    except Exception as e:
        print(f"❌ Exception: {type(e).__name__}: {e}")
        return None

if __name__ == "__main__":
    print("=" * 70)
    print("TEST OLLAMA DIRECTO")
    print("=" * 70)
    print()
    
    test_ollama("Di hola en una palabra")
    print()
    print("=" * 70)
