#!/bin/bash
# KLAWAQUA-AGI: Telegram → Hermes Directo
# Sin ThePopebot, sin OpenRouter, solo qwen3.5:4b local

set -euo pipefail

# Configuración
BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
OFFSET_FILE="/tmp/telegram_hermes.offset"
LOG_FILE="/tmp/telegram_hermes.log"

if [ -z "$BOT_TOKEN" ]; then
    if [ -f "$HOME/.hermes/.env" ]; then
        source "$HOME/.hermes/.env"
    fi
fi

if [ -z "$BOT_TOKEN" ]; then
    echo "❌ TELEGRAM_BOT_TOKEN no configurado"
    exit 1
fi

log() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

get_offset() {
    cat "$OFFSET_FILE" 2>/dev/null || echo "0"
}

set_offset() {
    echo "$1" > "$OFFSET_FILE"
}

# Process message with HERMES LOCAL (qwen3.5:4b)
process_with_hermes() {
    local chat_id="$1"
    local text="$2"
    
    log "Procesando con Hermes (qwen3.5:4b local): $text"
    
    # Usar Hermes one-shot mode con timeout de 60s
    local response
    response=$(timeout 60 hermes -z "$text" 2>&1) || {
        response="⚠️ Error al procesar. Intenta de nuevo."
    }
    
    # Trim y limitar longitud
    response=$(echo "$response" | head -100)
    
    log "Respuesta: ${response:0:100}..."
    
    # Enviar respuesta
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="$chat_id" \
        -d text="$response" \
        -d parse_mode="Markdown" \
        > /dev/null
}

# Main loop
log "=========================================="
log "Telegram → Hermes (qwen3.5:4b local)"
log "Bot: ...${BOT_TOKEN: -6}"
log "=========================================="

[ ! -f "$OFFSET_FILE" ] && echo "0" > "$OFFSET_FILE"

while true; do
    offset=$(get_offset)
    
    # Long polling (25s timeout)
    response=$(curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates" \
        -d offset="$offset" \
        -d timeout=25 \
        -d limit=100)
    
    # Check if ok
    status=$(echo "$response" | jq -r '.ok' 2>/dev/null)
    
    if [ "$status" != "true" ]; then
        log "Error Telegram API: $(echo "$response" | jq -r '.description' 2>/dev/null)"
        sleep 5
        continue
    fi
    
    # Process each update
    echo "$response" | jq -c '.result[]' 2>/dev/null | while read -r update; do
        update_id=$(echo "$update" | jq -r '.update_id')
        
        # Extract message
        if echo "$update" | jq -e '.message' > /dev/null 2>&1; then
            chat_id=$(echo "$update" | jq -r '.message.chat.id')
            msg_text=$(echo "$update" | jq -r '.message.text // ""')
            
            # Ignore empty or bot messages
            if [ -n "$msg_text" ]; then
                log "Mensaje de $chat_id: $msg_text"
                process_with_hermes "$chat_id" "$msg_text"
            fi
        fi
        
        # Update offset
        set_offset $((update_id + 1))
    done
done
