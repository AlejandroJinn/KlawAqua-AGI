#!/bin/bash
# KLAWAQUA-AGI: Telegram Poller - Single Instance Manager
# Garantiza que solo UNA instancia del poller corra

PIDFILE="/tmp/telegram_poller.pid"
LOGFILE="/tmp/telegram_poller.log"
OFFSET_FILE="/tmp/telegram_poller.offset"
POLL_SCRIPT="$HOME/.hermes/skills/devops/telegram-poller/scripts/poll.sh"

# Check if already running
if [ -f "$PIDFILE" ]; then
    OLD_PID=$(cat "$PIDFILE")
    if ps -p "$OLD_PID" > /dev/null 2>&1; then
        echo "✅ Telegram Poller YA está corriendo (PID: $OLD_PID)"
        echo "Para reiniciar: $0 restart"
        exit 0
    else
        echo "Limpiando PID file de proceso muerto..."
        rm -f "$PIDFILE"
    fi
fi

# Cargar variables de entorno
if [ -f "$HOME/.hermes/.env" ]; then
    source "$HOME/.hermes/.env"
fi

# Verificar token
if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
    echo "❌ TELEGRAM_BOT_TOKEN no configurado"
    echo "Agrega a ~/.hermes/.env:"
    echo "  export TELEGRAM_BOT_TOKEN=tu_token"
    exit 1
fi

echo "=================================================="
echo "   KLAWAQUA-AGI: Iniciando Telegram Poller"
echo "=================================================="
echo ""
echo "Bot: ...${TELEGRAM_BOT_TOKEN: -6}"
echo "Token: $TELEGRAM_USE_POLLING"

# Reset offset si no existe
[ ! -f "$OFFSET_FILE" ] && echo "0" > "$OFFSET_FILE"

# Iniciar poller en background
nohup bash "$POLL_SCRIPT" > "$LOGFILE" 2>&1 &
POLLER_PID=$!

# Guardar PID
echo "$POLLER_PID" > "$PIDFILE"

sleep 3

# Verificar que está corriendo
if ps -p "$POLLER_PID" > /dev/null 2>&1; then
    echo ""
    echo "✅ Telegram Poller ACTIVO (PID: $POLLER_PID)"
    echo ""
    echo "Logs: tail -f $LOGFILE"
    echo "Detener: $0 stop"
    echo "Estado: $0 status"
    echo ""
else
    echo "❌ Error al iniciar. Ver $LOGFILE"
    rm -f "$PIDFILE"
    exit 1
fi
