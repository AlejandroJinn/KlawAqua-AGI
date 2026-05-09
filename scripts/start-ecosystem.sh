#!/usr/bin/env bash
# Flujo de trabajo para activar ngrok y asegurar que thepopebot esté operativo
# Ubicado en /opt/klawaqua/scripts/start-ecosystem.sh

set -euo pipefail

LOG_DIR="$HOME/logs"
LOG_FILE="$LOG_DIR/klawaqua-ecosystem.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Ensure log directory exists
mkdir -p "$LOG_DIR"

log() {
    echo "[$TIMESTAMP] $1" | tee -a "$LOG_FILE"
}

# 1. Verificar y activar ngrok
log "Verificando estado de ngrok..."
if pgrep -x "ngrok" > /dev/null; then
    log "ngrok ya está ejecutándose."
else
    log "Iniciando ngrok en puerto 8080 (interfaz web de thepopebot)..."
    ngrok http 8080 --log=stdout > /tmp/ngrok.log 2>&1 &
    NGROK_PID=$!
    # Esperar a que ngrok inicialice su API
    for i in {1..10}; do
        if curl -s http://localhost:4040/api/tunnels > /dev/null; then
            log "ngrok iniciado correctamente (PID: $NGROK_PID)."
            break
        fi
        sleep 1
    done
    if ! curl -s http://localhost:4040/api/tunnels > /dev/null; then
        log "ERROR: ngrok no respondió tras el arranque."
        exit 1
    fi
fi

# Obtener URL pública de ngrok
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url // empty')
if [[ -z "$NGROK_URL" ]]; then
    log "ERROR: No se pudo obtener la URL pública de ngrok."
    exit 1
fi
log "URL pública de ngrok: $NGROK_URL"

# 2. Verificar servicios de thepopebot
log "Verificando servicios de thepopebot..."
cd /opt/klawaqua/projects/thepopebot || { log "ERROR: No se encontró el directorio de thepopebot."; exit 1; }

# Lista de servicios esperados
SERVICES="thepopebot-event-handler thepopebot-instance-litellm-1 thepopebot-instance-traefik-1 thepopebot-instance-runner-1"

ALL_UP=true
for SERVICE in $SERVICES; do
    if ! docker ps --format '{{.Names}}' | grep -q "^$SERVICE$"; then
        log "Servicio $SERVICE no está en ejecución. Intentando iniciar..."
        # Intentar levantar solo ese servicio mediante docker-compose
        docker compose up -d "$SERVICE" || log "ADVERTENCIA: No se pudo iniciar $SERVICE automáticamente."
    else
        log "Servicio $SERVICE: OK"
    fi
done

# Verificar salud del event-handler (opcional)
if docker inspect thepopebot-event-handler --format '{{.State.Health.Status}}' 2>/dev/null | grep -q "healthy"; then
    log "thepopebot-event-handler está healthy."
else
    log "ADVERTENCIA: thepopebot-event-handler no reporta healthy (puede estar inicializando)."
fi

# 3. Verificar que Ollama esté disponible (backend de modelos)
log "Verificando Ollama backend..."
if curl -s http://localhost:11434/api/tags > /dev/null; then
    log "Ollama responde correctamente en puerto 11434."
else
    log "ERROR: Ollama no responde en puerto 11434."
fi

# 4. Resumen final
log "===== FLUJO DE TRABAJO COMPLETADO ====="
log "Ngrok URL: $NGROK_URL"
log "ThePopeBot servicios: verifica con 'docker ps --filter \"name=thepopebot\"'"
log "Acceso a la interfaz web: $NGROK_URL"
log "Logs completos en: $LOG_FILE"
echo
echo "🚀 Ecosistema KlawAqua + OpenClaw listo para usar."
echo "🔗 Interfaz web segura: $NGROK_URL"
echo "💡 Sugerencia: Usa este URL para acceder a la UI de thepepebot desde cualquier lugar."