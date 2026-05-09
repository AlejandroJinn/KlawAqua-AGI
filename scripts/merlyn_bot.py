#!/usr/bin/env python3
"""
Merlyn Bot - Telegram Gateway para KlawAqua-AGI
Conecta Telegram ↔ Router Mesh (localhost:9000)
Usuario autorizado: Alejandro Giraldo (364536797)
"""
import os, sys, json, time, urllib.request, urllib.error

TOKEN = "8469591478:AAGjPrpL5XR7Igh0fqp-JeL6Tma8NMEDEy8"
ALLOWED_USER = 364536797  # Alejandro Giraldo
ROUTER_URL = "http://localhost:9000"
OFFSET_FILE = "/tmp/merlyn_bot.offset"

def tg_api(method, data=None):
    """Llama a la API de Telegram"""
    url = f"https://api.telegram.org/bot{TOKEN}/{method}"
    try:
        body = json.dumps(data).encode() if data else None
        req = urllib.request.Request(url, data=body, method="POST")
        if data:
            req.add_header("Content-Type", "application/json")
        resp = urllib.request.urlopen(req, timeout=30)
        return json.loads(resp.read().decode())
    except Exception as e:
        print(f"[ERROR] Telegram API: {e}")
        return None

def send_message(chat_id, text):
    """Envía mensaje a Telegram"""
    return tg_api("sendMessage", {
        "chat_id": chat_id,
        "text": text,
        "parse_mode": "HTML"
    })

def process_command(chat_id, text):
    """Procesa comandos del ecosistema"""
    cmd = text.strip().lower()
    
    # Comandos rápidos sin LLM
    if cmd == "/start":
        return """🤖 <b>Merlyn Bot - KlawAqua AGI</b>

Comandos disponibles:
/estado - Estado del ecosistema
/servicios - Lista de servicios
/vram - Estado GPU
/avatar [texto] - Avatar hablando
/chat [texto] - Conversación con IA
/dashboard - Link al dashboard
/ayuda - Esta ayuda"""
    
    elif cmd == "/estado" or cmd == "/status":
        try:
            resp = urllib.request.urlopen(f"{ROUTER_URL}/health", timeout=5)
            data = json.loads(resp.read().decode())
            return f"""📊 <b>KlawAqua-AGI</b>
Modo: {data.get('mode','?')}
Modelo local: {data.get('local_model','?')}
Ollama: {'✅' if data.get('ollama') else '❌'}"""
        except:
            return "❌ No pude conectar con el Router"
    
    elif cmd == "/servicios" or cmd == "/services":
        try:
            resp = urllib.request.urlopen(f"{ROUTER_URL}/mesh/status", timeout=5)
            data = json.loads(resp.read().decode())
            lines = ["🔌 <b>Servicios KlawAqua:</b>"]
            for svc, status in sorted(data.items()):
                icon = "🟢" if status == "online" else "🔴"
                lines.append(f"{icon} {svc}")
            return "\n".join(lines)
        except:
            return "❌ Error consultando servicios"
    
    elif cmd == "/vram":
        import subprocess
        r = subprocess.run(["nvidia-smi", "--query-gpu=memory.used,memory.total,temperature.gpu",
                          "--format=csv,noheader"], capture_output=True, text=True, timeout=5)
        return f"🎮 <b>GPU:</b> {r.stdout.strip()}"
    
    elif cmd.startswith("/avatar "):
        text_to_speak = text[8:].strip()
        if not text_to_speak:
            return "Uso: /avatar texto para que el avatar hable"
        send_message(chat_id, "🎌 Generando avatar parlante...")
        try:
            data = json.dumps({
                "text": text_to_speak,
                "avatar": "waifu_20260509_080634",
                "method": "ffmpeg"
            }).encode()
            req = urllib.request.Request("http://localhost:8002/avatar/speak", data=data)
            req.add_header("Content-Type", "application/json")
            resp = urllib.request.urlopen(req, timeout=60)
            result = json.loads(resp.read().decode())
            return f"✅ Avatar generado: {result['duration_s']}s\n📁 {result['video_path']}"
        except Exception as e:
            return f"❌ Error avatar: {e}"
    
    elif cmd.startswith("/chat "):
        prompt = text[6:].strip()
        send_message(chat_id, "💭 Pensando...")
        try:
            data = json.dumps({"prompt": prompt, "conversation_id": str(chat_id)}).encode()
            req = urllib.request.Request(f"{ROUTER_URL}/chat", data=data)
            req.add_header("Content-Type", "application/json")
            resp = urllib.request.urlopen(req, timeout=60)
            result = json.loads(resp.read().decode())
            response = result.get("response", "")[:500]
            src = result.get("source", "?")
            model = result.get("model", "?")
            return f"{response}\n\n<sub>{src}/{model}</sub>"
        except Exception as e:
            return f"❌ Error: {e}"
    
    elif cmd == "/dashboard":
        return "📊 Dashboard: http://localhost:8002/dashboard/"
    
    elif cmd == "/ayuda" or cmd == "/help":
        return process_command(chat_id, "/start")
    
    else:
        # Cualquier otro texto → LLM via Router
        send_message(chat_id, "💭 Pensando...")
        try:
            data = json.dumps({"prompt": text, "conversation_id": str(chat_id)}).encode()
            req = urllib.request.Request(f"{ROUTER_URL}/chat", data=data)
            req.add_header("Content-Type", "application/json")
            resp = urllib.request.urlopen(req, timeout=60)
            result = json.loads(resp.read().decode())
            return result.get("response", "No pude procesar tu mensaje")[:500]
        except:
            return "❌ Error conectando con la IA local"

def get_offset():
    try:
        with open(OFFSET_FILE) as f:
            return int(f.read().strip()) + 1
    except:
        return 0

def save_offset(offset):
    with open(OFFSET_FILE, "w") as f:
        f.write(str(offset))

def main():
    print(f"🤖 Merlyn Bot iniciado (user={ALLOWED_USER})")
    print(f"   Router: {ROUTER_URL}")
    
    # Mensaje de inicio
    send_message(ALLOWED_USER, "🟢 <b>Merlyn Bot - KlawAqua AGI</b>\nEcosistema activo. Envía /ayuda para ver comandos.")
    
    while True:
        try:
            offset = get_offset()
            result = tg_api("getUpdates", {
                "offset": offset,
                "timeout": 25,
                "limit": 10,
                "allowed_updates": ["message"]
            })
            
            if result and result.get("ok") and result.get("result"):
                for update in result["result"]:
                    msg = update.get("message", {})
                    chat_id = msg.get("chat", {}).get("id", 0)
                    text = msg.get("text", "")
                    
                    if chat_id == ALLOWED_USER and text:
                        print(f"[{time.strftime('%H:%M:%S')}] {text[:80]}")
                        response = process_command(chat_id, text)
                        send_message(chat_id, response)
                    
                    save_offset(update["update_id"])
            
            time.sleep(1)
            
        except KeyboardInterrupt:
            print("\n👋 Bot detenido")
            break
        except Exception as e:
            print(f"[ERROR] {e}")
            time.sleep(5)

if __name__ == "__main__":
    main()