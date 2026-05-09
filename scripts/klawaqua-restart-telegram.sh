#!/bin/bash
set -e
BOT_TOKEN=8467732148:AAFdj1GXDYFaUrIOq_ZUxp56ac0BnU17LYc

# Matar pollers viejos
pkill -9 -f 'telegram-hermes' 2>/dev/null || true
pkill -9 -f 'merlyn_bot' 2>/dev/null || true
sleep 2

# Liberar token
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/deleteWebhook?drop_pending_updates=true" >/dev/null 2>&1
sleep 3

# Limpiar logs
> /tmp/telegram_hermes.log 2>/dev/null || true
> /tmp/telegram_hermes.offset 2>/dev/null || true
rm -f /tmp/telegram_hermes.pid 2>/dev/null || true

# Iniciar UNICO poller
TELEGRAM_BOT_TOKEN=$BOT_TOKEN nohup bash /opt/klawaqua/scripts/telegram-hermes-direct.sh > /tmp/telegram_hermes.log 2>&1 &
echo "Telegram poller started PID $!"
sleep 5

# Verificar
if grep -q "409\|Conflict" /tmp/telegram_hermes.log 2>/dev/null; then
    echo "WARNING: Still getting 409"
    tail -3 /tmp/telegram_hermes.log 2>/dev/null || true
else
    echo "OK: No conflicts"
    echo "Poller PID: $(pgrep -f 'telegram-hermes-direct' 2>/dev/null || echo 'not found')"
fi
