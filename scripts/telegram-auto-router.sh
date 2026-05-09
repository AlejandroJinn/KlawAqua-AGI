#!/bin/bash
# KLAWAQUA-AGI: Telegram con Auto Router
# Procesa mensajes con router automático local↔cloud

set -euo pipefail

BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
OFFSET_FILE="/tmp/telegram_router.offset"
LOG_FILE="/tmp/telegram_router.log"

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

# Process with auto-router
process_with_auto_router() {
    local chat_id="$1"
    local text="$2"
    
    log "🔄 Router: Procesando: $text"
    
    # Usar Python auto-router
    local start_time=$(date +%s%3N)
    
    result=$(python3 /opt/klawaqua/scripts/hermes_auto_router.py << EOF
import sys
sys.path.insert(0, '/opt/klawaqua/scripts')
from hermes_auto_router import route_query

prompt = '''$text'''
response, model, source = route_query(prompt, conversation_id="$chat_id")
print(f"{response}\n---MODEL:{model}\n---SOURCE:{source}")
EOF
) || {
        response="⚠️ Error procesando con auto-router"
        log "❌ Error en auto-router"
    }
    
    # Parsear resultado
    response=$(echo "$result" | sed -n '1p')
    model=$(echo "$result" | grep "MODEL:" | cut -d: -f2)
    source=$(echo "$result" | grep "SOURCE:" | cut -d: -f2)
    
    local end_time=$(date +%s%3N)
    local latency=$((end_time - start_time))
    
    log "✅ Router: $model ($source) - ${latency}ms"
    
    # Enviar respuesta
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="$chat_id" \
        -d text="$response" \
        -d parse_mode="Markdown" \
        > /dev/null
    
    # Opcional: enviar info del modelo usado
    if [ "$VERBOSE" = "true" ]; then
        curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
            -d chat_id="$chat_id" \
            -d text="📊 Usé: *$model*$source)⏱️${latency}ms" \
            -d parse_mode="Markdown" \
            > /dev/null
    fi
}

# Main loop
log "=========================================="
log "Telegram → Auto Router (Local↔Cloud)"
log "Bot: ...${BOT_TOKEN: -6}"
log "=========================================="

[ ! -f "$OFFSET_FILE" ] && echo "0" > "$OFFSET_FILE"

while true; do
    offset=$(cat "$OFFSET_FILE" 2>/dev/null || echo "0")
    
    # Long polling (25s)
    response=$(curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates" \
        -d offset="$offset" \
        -d timeout=25 \
        -d limit=100)
    
    status=$(echo "$response" | jq -r '.ok' 2>/dev/null || echo "false")
    
    if [ "$status" != "true" ]; then
        log "❌ Error Telegram: $(echo "$response" | jq -r '.description' 2>/dev/null || echo 'Unknown')"
        sleep 5
        continue
    fi
    
    # Procesar updates
    echo "$response" | jq -c '.result[]' 2>/dev/null | while read -r update; do
        update_id=$(echo "$update" | jq -r '.update_id')
        
        if echo "$update" | jq -e '.message' > /dev/null 2>&1; then
            chat_id=$(echo "$update" | jq -r '.message.chat.id')
            msg_text=$(echo "$update" | jq -r '.message.text // ""')
            
            if [ -n "$msg_text" ]; then
                log "💬 Mensaje de $chat_id: $msg_text"
                process_with_auto_router "$chat_id" "$msg_text"
            fi
        fi
        
        # Update offset
        echo $((update_id + 1)) > "$OFFSET_FILE"
    done
done
