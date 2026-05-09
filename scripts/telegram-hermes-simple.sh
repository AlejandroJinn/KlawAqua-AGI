#!/bin/bash
# KLAWAQUA-AGI: Telegram → Hermes Agent (Simple & Robust)
# Solo UNA instancia, sin conflictos

set -euo pipefail

BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-8467732148:AAFdj1GXDYFaUrIOq_ZUxp56ac0BnU17LYc}"
OFFSET_FILE="/tmp/tg_hermes.offset"
LOG_FILE="/tmp/tg_hermes.log"
PID_FILE="/tmp/tg_hermes.pid"

# Guardar PID
echo $$ > "$PID_FILE"

log() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Verificar UNA sola instancia
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if [ "$OLD_PID" != "$$" ] && ps -p "$OLD_PID" > /dev/null 2>&1; then
        log "❌ Ya hay otra instancia corriendo (PID: $OLD_PID)"
        exit 1
    fi
fi

log "========================================"
log "Telegram → Hermes (qwen3.5:4b local)"
log "Bot: ...${BOT_TOKEN: -6}"
log "========================================"

[ ! -f "$OFFSET_FILE" ] && echo "0" > "$OFFSET_FILE"

while true; do
    offset=$(cat "$OFFSET_FILE" 2>/dev/null || echo "0")
    
    # Long polling con timeout de 30s
    response=$(curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates" \
        -d "offset=$offset" \
        -d "timeout=30" \
        -d "limit=10" 2>&1)
    
    # Verificar error HTTP
    http_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
        "https://api.telegram.org/bot${BOT_TOKEN}/getMe" 2>&1)
    
    if [ "$http_code" = "400" ]; then
        log "❌ Error HTTP 400 - Token inválido o bot bloqueado"
        sleep 10
        continue
    fi
    
    if [ "$http_code" = "401" ]; then
        log "❌ Error HTTP 401 - Token incorrecto"
        sleep 10
        continue
    fi
    
    # Parsear respuesta
    ok=$(echo "$response" | jq -r '.ok' 2>/dev/null || echo "false")
    
    if [ "$ok" != "true" ]; then
        error=$(echo "$response" | jq -r '.description' 2>/dev/null || echo "Unknown error")
        log "⚠️ Error API: $error"
        
        # Si es conflicto de instancias, esperar y continuar
        if echo "$error" | grep -qi "conflict"; then
            log "⏳ Esperando 5s por conflicto..."
            sleep 5
            # Reset offset para evitar loop
            echo "0" > "$OFFSET_FILE"
        fi
        sleep 2
        continue
    fi
    
    # Procesar updates
    count=$(echo "$response" | jq -r '.result | length' 2>/dev/null || echo "0")
    
    if [ "$count" -gt 0 ]; then
        log "📨 Recibidos $count mensajes"
        
        echo "$response" | jq -c '.result[]' 2>/dev/null | while read -r update; do
            update_id=$(echo "$update" | jq -r '.update_id')
            
            # Extraer mensaje
            if echo "$update" | jq -e '.message' > /dev/null 2>&1; then
                chat_id=$(echo "$update" | jq -r '.message.chat.id')
                msg_text=$(echo "$update" | jq -r '.message.text // ""')
                
                if [ -n "$msg_text" ]; then
                    log "💬 [$chat_id]: $msg_text"
                    
                    # Procesar con Hermes
                    start_time=$(date +%s%3N)
                    
                    response_text=$(timeout 60 hermes -z "$msg_text" 2>&1) || {
                        response_text="⚠️ Error procesando tu mensaje. Intenta de nuevo."
                    }
                    
                    latency=$(($(date +%s%3N) - start_time))
                    log "✅ Respuesta en ${latency}ms: ${response_text:0:50}..."
                    
                    # Enviar respuesta
                    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
                        -d "chat_id=$chat_id" \
                        -d "text=$response_text" \
                        -d "parse_mode=HTML" > /dev/null 2>&1 || \
                        log "❌ Error enviando respuesta"
                fi
            fi
            
            # Actualizar offset
            echo $((update_id + 1)) > "$OFFSET_FILE"
        done
    fi
done
