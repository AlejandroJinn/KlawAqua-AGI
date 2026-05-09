#!/usr/bin/env python3
"""
KLAWAQUA-AGI: Merlyn_bot Daemon (Directo con Ollama)
Telegram Bot exclusivo - Conecta DIRECTO a Ollama sin Hermes CLI
Token: 8469591478:AAGjPrpL5XR7Igh0fqp-JeL6Tma8NMEDEy8
"""

import os
import sys
import time
import signal
import requests
from pathlib import Path
from datetime import datetime

# Configuración
BOT_TOKEN = "8469591478:AAGjPrpL5XR7Igh0fqp-JeL6Tma8NMEDEy8"
BOT_NAME = "Merlyn_bot"
PID_FILE = "/tmp/merlyn_bot.pid"
OFFSET_FILE = "/tmp/merlyn_bot.offset"
LOG_FILE = "/tmp/merlyn_bot.log"

# Ollama config
OLLAMA_BASE = "http://localhost:11434"
DEFAULT_MODEL = "mistral:7b"  # Más rápido que qwen3.5:4b
FALLBACK_MODEL = "qwen2.5:0.5b"  # Muy rápido para consultas simples

def log(msg):
    timestamp = datetime.now().strftime('%H:%M:%S')
    line = f"[{timestamp}] {msg}"
    print(line, flush=True)
    with open(LOG_FILE, 'a') as f:
        f.write(line + '\n')

def check_pid():
    if Path(PID_FILE).exists():
        try:
            old_pid = int(Path(PID_FILE).read_text().strip())
            os.kill(old_pid, 0)
            log(f"❌ Ya hay una instancia (PID: {old_pid})")
            sys.exit(1)
        except (ProcessLookupError, ValueError):
            log("Limpiando PID file viejo")
            Path(PID_FILE).unlink()

def save_pid():
    Path(PID_FILE).write_text(str(os.getpid()))

def cleanup():
    log("🛑 Deteniendo Merlyn_bot...")
    if Path(PID_FILE).exists():
        Path(PID_FILE).unlink()
    sys.exit(0)

def get_updates(offset, timeout=30):
    url = f"https://api.telegram.org/bot{BOT_TOKEN}/getUpdates"
    data = {'offset': offset, 'timeout': timeout, 'limit': 10}
    try:
        r = requests.post(url, json=data, timeout=timeout + 5)
        return r.json()
    except Exception as e:
        return {'ok': False, 'description': str(e)}

def send_message(chat_id, text):
    url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
    data = {'chat_id': chat_id, 'text': text, 'parse_mode': 'HTML'}
    try:
        r = requests.post(url, json=data, timeout=10)
        return r.json().get('ok', False)
    except:
        return False

def generate_with_ollama(prompt, model=DEFAULT_MODEL):
    """Generar respuesta DIRECTAMENTE con Ollama"""
    url = f"{OLLAMA_BASE}/api/generate"
    data = {
        'model': model,
        'prompt': prompt,
        'stream': False,
        'options': {
            'temperature': 0.7,
            'top_p': 0.9
        }
    }
    
    try:
        r = requests.post(url, json=data, timeout=60)
        if r.status_code == 200:
            result = r.json()
            return result.get('response', 'No obtuve una respuesta clara.')
        else:
            return f"Error Ollama: HTTP {r.status_code}"
    except requests.exceptions.Timeout:
        return "⏱️ Tardé demasiado. Intenta de nuevo."
    except Exception as e:
        return f"⚠️ Error: {str(e)}"

def main():
    signal.signal(signal.SIGTERM, lambda sig, frame: cleanup())
    signal.signal(signal.SIGINT, lambda sig, frame: cleanup())
    
    check_pid()
    save_pid()
    
    log("=" * 60)
    log(f"🤖 MERLYN_BOT - KLAWAQUA-AGI")
    log(f"Bot: @{BOT_NAME}")
    log(f"Token: ...{BOT_TOKEN[-6:]}")
    log("=" * 60)
    log("✅ Iniciando... (CONEXIÓN DIRECTA A OLLAMA)")
    log(f"📍 Modelo: {DEFAULT_MODEL}")
    log(f"🔗 Ollama: {OLLAMA_BASE}")
    log("=" * 60)
    
    # Verificar Ollama
    try:
        r = requests.get(f"{OLLAMA_BASE}/api/tags", timeout=5)
        if r.status_code == 200:
            models = r.json().get('models', [])
            log(f"✅ Ollama responde ({len(models)} modelos)")
            if any(DEFAULT_MODEL in m.get('name', '') for m in models):
                log(f"✅ Modelo {DEFAULT_MODEL} disponible")
            else:
                log(f"⚠️ Modelo {DEFAULT_MODEL} NO encontrado en Ollama")
        else:
            log(f"⚠️ Ollama HTTP {r.status_code}")
    except Exception as e:
        log(f"❌ Ollama no responde: {e}")
    
    offset = 0
    if Path(OFFSET_FILE).exists():
        try:
            offset = int(Path(OFFSET_FILE).read_text().strip())
        except:
            pass
    
    consecutive_errors = 0
    
    while True:
        result = get_updates(offset, timeout=30)
        
        if not result.get('ok'):
            error = result.get('description', 'Unknown')
            log(f"⚠️ Error Telegram: {error}")
            
            if 'Conflict' in error:
                log("⏳ Esperando 10s por conflicto...")
                time.sleep(10)
                offset = 0
            else:
                time.sleep(5)
            
            consecutive_errors += 1
            if consecutive_errors > 10:
                log("❌ Demasiados errores, reiniciando...")
                consecutive_errors = 0
                time.sleep(10)
            continue
        
        consecutive_errors = 0
        updates = result.get('result', [])
        
        if updates:
            log(f"📨 {len(updates)} mensaje(s)")
            
            for update in updates:
                update_id = update.get('update_id')
                message = update.get('message', {})
                
                if message:
                    chat_id = message.get('chat', {}).get('id')
                    from_user = message.get('from', {}).get('first_name', 'User')
                    text = message.get('text', '')
                    
                    if text and chat_id:
                        log(f"💬 [{from_user}]: {text[:50]}...")
                        
                        # Generar con Ollama DIRECTO
                        start = time.time()
                        response = generate_with_ollama(text)
                        latency = int((time.time() - start) * 1000)
                        
                        log(f"✅ {latency}ms ({DEFAULT_MODEL}): {response[:60]}...")
                        
                        # Responder
                        if send_message(chat_id, response):
                            log("✓ Enviado")
                        else:
                            log("❌ Error al enviar")
                
                offset = max(offset, update_id + 1)
                Path(OFFSET_FILE).write_text(str(offset))
        
        time.sleep(1)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        cleanup()
    except Exception as e:
        log(f"💥 Fatal: {e}")
        cleanup()
