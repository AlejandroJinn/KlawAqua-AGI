#!/usr/bin/env python3
"""
KLAWAQUA-AGI: Telegram Manager Daemon
Gestiona UNA sola instancia del bot sin conflictos
"""

import os
import sys
import time
import signal
import requests
import subprocess
from pathlib import Path
from datetime import datetime

PID_FILE = "/tmp/telegram_bot.pid"
OFFSET_FILE = "/tmp/telegram_bot.offset"
LOG_FILE = "/tmp/telegram_bot.log"
BOT_TOKEN = os.getenv('TELEGRAM_BOT_TOKEN', '8467732148:AAFdj1GXDYFaUrIOq_ZUxp56ac0BnU17LYc')

def log(msg):
    timestamp = datetime.now().strftime('%H:%M:%S')
    line = f"[{timestamp}] {msg}"
    print(line)
    with open(LOG_FILE, 'a') as f:
        f.write(line + '\n')

def check_pid():
    """Verificar si ya hay una instancia"""
    if Path(PID_FILE).exists():
        try:
            old_pid = int(Path(PID_FILE).read_text().strip())
            # Verificar si el proceso existe
            os.kill(old_pid, 0)
            log(f"❌ Ya hay una instancia corriendo (PID: {old_pid})")
            sys.exit(1)
        except (ProcessLookupError, ValueError):
            log("Limpiando PID file de proceso muerto")
            Path(PID_FILE).unlink()

def save_pid():
    """Guardar PID actual"""
    Path(PID_FILE).write_text(str(os.getpid()))

def cleanup():
    """Limpieza al salir"""
    log("Deteniendo bot...")
    if Path(PID_FILE).exists():
        Path(PID_FILE).unlink()
    sys.exit(0)

def get_updates(offset, timeout=30):
    """Obtener updates de Telegram"""
    url = f"https://api.telegram.org/bot{BOT_TOKEN}/getUpdates"
    data = {'offset': offset, 'timeout': timeout, 'limit': 10}
    
    try:
        r = requests.post(url, json=data, timeout=timeout + 5)
        return r.json()
    except Exception as e:
        return {'ok': False, 'description': str(e)}

def send_message(chat_id, text):
    """Enviar mensaje"""
    url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
    data = {'chat_id': chat_id, 'text': text, 'parse_mode': 'HTML'}
    
    try:
        r = requests.post(url, json=data, timeout=10)
        return r.json().get('ok', False)
    except:
        return False

def process_with_hermes(text):
    """Procesar con Hermes"""
    try:
        result = subprocess.run(
            ['hermes', '-z', text],
            capture_output=True,
            text=True,
            timeout=60
        )
        return result.stdout.strip() or "No pude procesar eso."
    except subprocess.TimeoutExpired:
        return "⏱️ Timeout procesando tu mensaje."
    except Exception as e:
        return f"⚠️ Error: {str(e)}"

def main():
    # Signal handlers
    signal.signal(signal.SIGTERM, lambda sig, frame: cleanup())
    signal.signal(signal.SIGINT, lambda sig, frame: cleanup())
    
    check_pid()
    save_pid()
    
    log("=" * 50)
    log("KLAWAQUA-AGI Telegram Bot")
    log(f"Bot: ...{BOT_TOKEN[-6:]}")
    log("=" * 50)
    
    offset = 0
    if Path(OFFSET_FILE).exists():
        try:
            offset = int(Path(OFFSET_FILE).read_text().strip())
        except:
            pass
    
    log(f"Iniciando con offset: {offset}")
    
    consecutive_errors = 0
    
    while True:
        result = get_updates(offset, timeout=30)
        
        if not result.get('ok'):
            error = result.get('description', 'Unknown error')
            log(f"⚠️ Error API: {error}")
            
            if 'Conflict' in error:
                log("⏳ Esperando 10s por conflicto...")
                time.sleep(10)
                offset = 0  # Reset para evitar loop
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
            log(f"📨 {len(updates)} nuevo(s) mensaje(s)")
            
            for update in updates:
                update_id = update.get('update_id')
                message = update.get('message', {})
                
                if message:
                    chat_id = message.get('chat', {}).get('id')
                    text = message.get('text', '')
                    
                    if text and chat_id:
                        log(f"💬 [{chat_id}]: {text[:50]}...")
                        
                        # Procesar
                        start = time.time()
                        response = process_with_hermes(text)
                        latency = int((time.time() - start) * 1000)
                        
                        log(f"✅ {latency}ms: {response[:50]}...")
                        
                        # Responder
                        if send_message(chat_id, response):
                            log("✓ Enviado")
                        else:
                            log("❌ Error enviando")
                
                # Actualizar offset
                offset = max(offset, update_id + 1)
                Path(OFFSET_FILE).write_text(str(offset))
        
        time.sleep(1)

if __name__ == "__main__":
    main()
