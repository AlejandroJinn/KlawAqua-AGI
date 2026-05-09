#!/bin/bash
# KLAWAQUA-AGI: Telegram Bot Launcher con Exclusividad
# Usa flock para garantizar UNA sola instancia

LOCK_FILE="/tmp/klawaqua_telegram.lock"
PYTHON_SCRIPT="/opt/klawaqua/scripts/telegram_bot_daemon.py"
LOG_FILE="/opt/klawaqua/logs/telegram_launcher.log"

log() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=========================================="
log "KLAWAQUA-AGI Telegram Launcher"
log "=========================================="

# Intentar obtener lock exclusivo (no bloqueante)
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
    OLD_PID=$(cat "$LOCK_FILE" 2>/dev/null)
    log "❌ Ya hay una instancia corriendo (PID: $OLD_PID)"
    log "Para detener: kill $OLD_PID o rm $LOCK_FILE"
    exit 1
fi

# Guardar PID
echo $$ > "$LOCK_FILE"
log "✅ Lock obtenido (PID: $$)"
log "Iniciando bot..."
log ""

# Ejecutar el daemon Python
export TELEGRAM_BOT_TOKEN="8467732148:AAFdj1GXDYFaUrIOq_ZUxp56ac0BnU17LYc"
python3 "$PYTHON_SCRIPT"

EXIT_CODE=$?
log ""
log "Bot detenido (exit code: $EXIT_CODE)"

# El lock se libera automáticamente al salir
