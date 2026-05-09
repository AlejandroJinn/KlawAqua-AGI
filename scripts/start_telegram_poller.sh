#!/bin/bash
# KLAWAQUA-AGI: Inicio Rápido Telegram Poller
# Activa el bot de Telegram para operación remota

set -e

echo "=================================================="
echo "   KLAWAQUA-AGI: Telegram Poller Setup"
echo "=================================================="
echo ""

# Paths
HERMES_HOME="$HOME/.hermes"
ENV_FILE="$HERMES_HOME/.env"
POLL_SCRIPT="$HERMES_HOME/skills/devops/telegram-poller/scripts/poll.sh"
OFFSET_FILE="/tmp/telegram_poller.offset"

# Verificar variables de entorno
echo "[1/4] Verificando configuración..."

if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
    # Try to load from .env
    if [ -f "$ENV_FILE" ]; then
        source "$ENV_FILE"
    fi
fi

if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
    echo "❌ TELEGRAM_BOT_TOKEN no configurado"
    echo ""
    echo "Para configurar:"
    echo "  1. Crea un bot con @BotFather en Telegram"
    echo "  2. Agrega a ~/.hermes/.env:"
    echo "     export TELEGRAM_BOT_TOKEN=123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"
    echo "     export TELEGRAM_USE_POLLING=true"
    echo "     export TELEGRAM_CHAT_ID=tu_chat_id"
    echo ""
    echo "O ejecuta:"
    echo "  export TELEGRAM_BOT_TOKEN=tu_token"
    echo "  export TELEGRAM_USE_POLLING=true"
    echo "  $0"
    exit 1
fi

echo "  ✓ Bot token configurado (...${TELEGRAM_BOT_TOKEN: -6})"

# Verificar jq
if ! command -v jq &> /dev/null; then
    echo "  ⚠ jq no instalado, intentando instalar..."
    sudo apt install -y jq 2>/dev/null || {
        echo "  ❌ No se pudo instalar jq (se requiere sudo)"
        exit 1
    }
fi
echo "  ✓ jq disponible"

# Verificar script poller
if [ ! -f "$POLL_SCRIPT" ]; then
    echo "❌ Script poller no encontrado: $POLL_SCRIPT"
    exit 1
fi
chmod +x "$POLL_SCRIPT"
echo "  ✓ Poll script listo"

# Iniciar poller en background
echo ""
echo "[2/4] Iniciando Telegram Poller..."

# Matar instancias previas
pkill -f "poll.sh" 2>/dev/null || true
sleep 1

# Reset offset para empezar fresco
echo "0" > "$OFFSET_FILE"
echo "  ✓ Offset reseteado"

# Iniciar en background
nohup bash "$POLL_SCRIPT" > /tmp/telegram_poller.log 2>&1 &
POLLER_PID=$!

sleep 2

if ps -p $POLLER_PID > /dev/null; then
    echo "  ✓ Poller iniciado (PID: $POLLER_PID)"
else
    echo "  ❌ Poller no inició. Revisa /tmp/telegram_poller.log"
    exit 1
fi

# Verificar conexión
echo ""
echo "[3/4] Verificando conexión con Telegram..."

TEST_RESPONSE=$(curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getMe" | jq -r '.ok' 2>/dev/null)

if [ "$TEST_RESPONSE" = "true" ]; then
    echo "  ✓ Conexión con Telegram exitosa"
else
    echo "  ❌ Error de conexión. Verifica el token."
    pkill -f "poll.sh"
    exit 1
fi

# Instrucciones finales
echo ""
echo "[4/4] ¡Telegram Poller ACTIVO!"
echo ""
echo "=================================================="
echo "   ESTADO: ✅ OPERATIVO"
echo "=================================================="
echo ""
echo "El bot está escuchando mensajes de Telegram."
echo ""
echo "Para usar:"
echo "  1. Envía un mensaje a tu bot desde Telegram"
echo "  2. El bot procesará con Hermes (qwen3.5:4b)"
echo "  3. Recibirás respuesta automáticamente"
echo ""
echo "Comando para detener:"
echo "  pkill -f 'poll.sh'"
echo ""
echo "Logs en tiempo real:"
echo "  tail -f /tmp/telegram_poller.log"
echo ""
echo "PID del poller: $POLLER_PID"
echo ""
echo "=================================================="

# Guardar PID para referencia
echo "$POLLER_PID" > /tmp/telegram_poller.pid
