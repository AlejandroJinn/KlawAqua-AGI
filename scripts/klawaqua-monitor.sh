#!/bin/bash
# KLAWAQUA-AGI: Monitor Auto-Recuperación
# Se ejecuta continuamente y reinicia servicios caídos

LOG=/tmp/klawaqua-monitor.log

log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG"
}

log_msg "🚀 Monitor auto-recuperación iniciado"

while true; do
    # 1. Check Ollama
    if ! curl -sf http://localhost:11434/ &>/dev/null; then
        log_msg "⚠️ Ollama caído - intentando reiniciar..."
        sudo systemctl restart ollama 2>/dev/null || echo "Requiere atención manual"
        sleep 5
    fi
    
    # 2. Check containers
    for container in agent-zero openhands-app redis-cache postgres-letta; do
        status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
        if [[ "$status" != "running" ]]; then
            log_msg "⚠️ Container $container: $status - reiniciando..."
            docker start "$container" 2>/dev/null
            sleep 3
        fi
    done
    
    # 3. Check Merlyn_bot
    if [[ -f /tmp/merlyn_bot.pid ]]; then
        pid=$(cat /tmp/merlyn_bot.pid)
        if ! kill -0 "$pid" 2>/dev/null; then
            log_msg "⚠️ Merlyn_bot caído (PID: $pid) - reiniciando..."
            nohup python3 /opt/klawaqua/scripts/merlyn_bot_direct.py > /tmp/merlyn_stdout.log 2>&1 &
            echo $! > /tmp/merlyn_bot.pid
        fi
    fi
    
    # 4. Check LiteLLM container
    ltl_status=$(docker inspect --format='{{.State.Status}}' litellm-klawaqua)
    if [[ "$ltl_status" != "running" ]]; then
        log_msg "⚠️ LiteLLM caído - reiniciando..."
        docker restart litellm-klawaqua 2>/dev/null
    fi
    
    sleep 300  # check each 5 minutes
done
