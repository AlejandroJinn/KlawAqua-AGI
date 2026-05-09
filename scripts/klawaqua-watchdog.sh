#!/bin/bash
# KLAWAQUA-AGI: Watchdog unificado con compose
# Un solo compose evita orphans. Monitor cada 3 min.
COMPOSE_FILE="/opt/klawaqua/klawaqua-docker-compose.yml"
ENV_FILE="/opt/klawaqua/.klawaqua.env"
LOG="/tmp/klawaqua-watchdog.log"
BOT_TOKEN="8467732148:AAFdj1GXDYFaUrIOq_ZUxp56ac0BnU17LYc"
TG_SCRIPT="/opt/klawaqua/scripts/telegram-hermes-direct.sh"
TG_LOG="/tmp/telegram_hermes.log"
INTERVAL=180

log() { echo "[$(date '+%H:%M:%S')] $1" >> "$LOG"; }
log "Watchdog iniciado (PID $$, cada ${INTERVAL}s)"

# ---- START COMPOSE (one-time bootstrap) ----
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d 2>&1 | tee -a "$LOG"
sleep 30
log "Compose inicializado"

# ---- CHECK HELPERS ----
compose_up() {
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d "$1" 2>&1 | tail -3 >> "$LOG"
}

check_port() {
    http=$(curl -s -m 5 -o /dev/null -w "%{http_code}" "http://localhost:$1$2" 2>/dev/null)
    echo "$http"
}

# ---- MAIN LOOP ----
tick=0
while true; do
    tick=$((tick + 1))
    log "=== Tick #$tick ==="

    # --- Ollama (base de todo) ---
    if ! curl -s -m 5 http://localhost:11434/api/tags >/dev/null 2>&1; then
        log "Ollama DOWN, restarting..."
        systemctl start ollama
        sleep 3
    fi

    # --- Compose services ---
    # Check all 6 containers in one pass
    running=$(docker compose -f "$COMPOSE_FILE" ps --format '{{.Name}} {{.Status}}' 2>/dev/null)
    for svc in redis postgres litellm event-handler openhands agent-zero; do
        if ! echo "$running" | grep -q "^${svc}.*Up"; then
            log "$svc DOWN, restarting..."
            compose_up "$svc"
            sleep 10
            # Verify
            r2=$(docker compose -f "$COMPOSE_FILE" ps --format '{{.Name}} {{.Status}}' 2>/dev/null)
            if echo "$r2" | grep -q "^${svc}.*Up"; then
                log "$svc RECOVERED"
            else
                log "$svc STILL DOWN"
            fi
        fi
    done

    # --- OpenCLAW ---
    if ! pgrep -f 'openclaw' >/dev/null 2>&1; then
        log "OpenCLAW DOWN, restarting..."
        cd /opt/klawaqua/projects/openclaw 2>/dev/null || cd /home/clarwis/openclaw 2>/dev/null || true
        openclaw gateway >> /tmp/openclaw-gateway.log 2>&1 &
        log "OpenCLAW restarted PID $!"
    fi

    # --- Router Service (port 9000) ---
    if [ "$(curl -s -m 5 -o /dev/null -w '%{http_code}' http://localhost:9000/health 2>/dev/null)" != "200" ]; then
        log "Router DOWN, restarting..."
        systemctl --user restart klawaqua-router.service 2>/dev/null || true
        sleep 3
        if [ "$(curl -s -m 5 -o /dev/null -w '%{http_code}' http://localhost:9000/health 2>/dev/null)" = "200" ]; then
            log "Router RECOVERED"
        else
            log "Router STILL DOWN"
        fi
    fi

    # --- OpenManus (port 8002) ---
    if [ "$(curl -s -m 5 -o /dev/null -w '%{http_code}' http://localhost:8002/health 2>/dev/null)" != "200" ]; then
        log "OpenManus DOWN, restarting..."
        systemctl --user restart klawaqua-openmanus.service 2>/dev/null || true
        sleep 3
        if [ "$(curl -s -m 5 -o /dev/null -w '%{http_code}' http://localhost:8002/health 2>/dev/null)" = "200" ]; then
            log "OpenManus RECOVERED"
        else
            log "OpenManus STILL DOWN"
        fi
    fi

    # --- Telegram ---
    # Kill ALL conflicting pollers first
    if pgrep -f 'telegram-hermes-direct' >/dev/null 2>&1; then
        if grep -q "409\|Conflict" "$TG_LOG" 2>/dev/null; then
            log "Telegram conflict, cleaning..."
            pkill -9 -f 'telegram-hermes-direct' 2>/dev/null || true
            sleep 2
            curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/deleteWebhook?drop_pending_updates=true" >/dev/null 2>&1
            sleep 3
            rm -f "$TG_LOG" /tmp/telegram_hermes.offset
            echo "0" > /tmp/telegram_hermes.offset
            TELEGRAM_BOT_TOKEN=$BOT_TOKEN nohup bash "$TG_SCRIPT" > "$TG_LOG" 2>&1 &
            log "Telegram restarted PID $!"
        fi
    else
        # Not running at all - start clean
        curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/deleteWebhook?drop_pending_updates=true" >/dev/null 2>&1
        sleep 3
        rm -f "$TG_LOG" /tmp/telegram_hermes.offset
        echo "0" > /tmp/telegram_hermes.offset
        TELEGRAM_BOT_TOKEN=$BOT_TOKEN nohup bash "$TG_SCRIPT" > "$TG_LOG" 2>&1 &
        log "Telegram started PID $!"
    fi

    sleep $INTERVAL
done
