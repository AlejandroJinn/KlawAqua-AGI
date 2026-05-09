#!/usr/bin/env python3
"""
KLAWAQUA-AGI: Notificador de Descarga Completa
Envía notificación a Telegram cuando termina una descarga de Ollama
"""

import requests
import sys
import subprocess
import time
from pathlib import Path

# Configuración Telegram
BOT_TOKEN = "8469591478:AAGjPrpL5XR7Igh0fqp-JeL6Tma8NMEDEy8"
CHAT_ID = "364536797"  # Alejandro's Telegram ID

def send_telegram_message(text):
    """Enviar mensaje a Telegram"""
    url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
    data = {
        'chat_id': CHAT_ID,
        'text': text,
        'parse_mode': 'HTML'
    }
    
    try:
        r = requests.post(url, json=data, timeout=10)
        return r.json().get('ok', False)
    except Exception as e:
        print(f"Error enviando Telegram: {e}")
        return False

def check_model_ready(model_name):
    """Verificar si el modelo está listo en Ollama"""
    try:
        result = subprocess.run(
            ['ollama', 'list'],
            capture_output=True,
            text=True,
            timeout=10
        )
        return model_name in result.stdout
    except:
        return False

def notify_completion(model_name, download_time):
    """Enviar notificación de descarga completada"""
    message = f"""
🎉 <b>¡Descarga Completada!</b>

📦 <b>Modelo:</b> {model_name}
⏱️ <b>Tiempo:</b> {download_time}
💾 <b>Tamaño:</b> ~4.9 GB
📍 <b>Ubicación:</b> ~/.ollama/models/

✅ <b>Estado:</b> Listo para usar

<b>Comandos útiles:</b>
• <code>ollama run {model_name}</code>
• <code>hermes config set main_model {model_name}</code>
• <code>ollama run {model_name} "Hola"</code>

═══════════════════════════════
KLAWAQUA-AGI Notifications
@Demberius_bot
    """
    
    return send_telegram_message(message)

def monitor_download(model_name, max_wait_minutes=90):
    """Monitorear descarga y notificar cuando termine"""
    print(f"🔍 Monitoreando descarga de {model_name}...")
    
    start_time = time.time()
    max_wait_seconds = max_wait_minutes * 60
    
    while True:
        elapsed = time.time() - start_time
        
        if elapsed > max_wait_seconds:
            print(f"⏰ Timeout después de {max_wait_minutes} minutos")
            send_telegram_message(f"⏰ <b>Timeout</b>\n\nLa descarga de {model_name} excedió el tiempo máximo ({max_wait_minutes} min)")
            return False
        
        if check_model_ready(model_name):
            elapsed_minutes = int(elapsed / 60)
            print(f"✅ {model_name} está listo!")
            
            # Enviar notificación
            success = notify_completion(model_name, f"{elapsed_minutes} minutos")
            
            if success:
                print("✅ Notificación enviada a Telegram")
            else:
                print("❌ Error enviando notificación")
            
            return True
        
        # Verificar cada 30 segundos
        time.sleep(30)
        remaining = int((max_wait_seconds - elapsed) / 60)
        print(f"⏳ Esperando... ({remaining} min restantes)", end="\r")

if __name__ == "__main__":
    model = sys.argv[1] if len(sys.argv) > 1 else "llama3.1:8b"
    
    print("=" * 60)
    print(f"KLAWAQUA-AGI: Monitor de Descarga")
    print(f"Modelo: {model}")
    print(f"Notificación: Telegram (@Demberius_bot)")
    print("=" * 60)
    
    # Enviar mensaje de inicio
    send_telegram_message(f"""
⏳ <b>Descarga en Progreso</b>

📦 <b>Modelo:</b> {model}
📊 <b>Tamaño:</b> ~4.9 GB
🔔 <b>Notificación:</b> Te avisaré cuando termine

═══════════════════════════════
KLAWAQUA-AGI
    """)
    
    # Monitorear
    success = monitor_download(model)
    
    sys.exit(0 if success else 1)
