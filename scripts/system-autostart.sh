#!/bin/bash
# ============================================================
# KlawAqua Auto-Start Completo - Se ejecuta al encender el PC
# Reinicia todo el ecosistema con memoria persistente
# ============================================================

LOG="/opt/klawaqua/logs/autostart.log"
echo "" >> $LOG
echo "=== $(date '+%Y-%m-%d %H:%M:%S') Auto-Start KlawAqua ===" >> $LOG

# 1. Ollama
echo "  Iniciando Ollama..." >> $LOG
if systemctl is-active --quiet ollama 2>/dev/null; then
    systemctl restart ollama
else
    /usr/local/bin/ollama serve &
fi
sleep 5 && curl -s -m 5 localhost:11434/ > /dev/null 2>&1 && echo "  ✅ Ollama OK" >> $LOG || echo "  ❌ Ollama FAIL" >> $LOG

# 2. Docker containers esenciales
echo "  Iniciando Docker..." >> $LOG
cd /opt/klawaqua/projects/thepopebot-instance
docker compose -f docker-compose.klawaqua.yml up -d >> $LOG 2>&1

# Agent Zero
docker start agent-zero 2>/dev/null
docker start openhands-app 2>/dev/null

# LiteLLM
docker start litellm-klawaqua 2>/dev/null
docker start litellm-proxy 2>/dev/null

# Redis y Postgres
docker start redis-cache 2>/dev/null
docker start postgres-letta 2>/dev/null

# ThePopeBot
docker start thepopebot-event-handler 2>/dev/null

# OpenFang (background)
sleep 3 && (export PATH=/opt/klawaqua/bin:$PATH && cd / && openfang start >> /opt/klawaqua/logs/openfang.log 2>&1) &

# 4. Router service (puerto 9000, local↔cloud free)
sleep 8 && python3 /opt/klawaqua/scripts/router_service.py >> $LOG 2>&1 &
echo $! > /opt/klawaqua/data/router_service.pid
sleep 3 && curl -s -m 5 http://localhost:9000/health > /dev/null && echo "  ✅ Router service OK (auto, local-first, free)" >> $LOG || echo "  ⚠️ Router service FAIL" >> $LOG

# 4b. Watchdog - monitorea router + ollama, auto-recovery
sleep 12 && python3 /opt/klawaqua/scripts/router_watchdog.py >> $LOG 2>&1 &
echo $! > /opt/klawaqua/data/router_watchdog.pid
echo "  ✅ Watchdog lanzado (check cada 30s)" >> $LOG

# 5. Init memoria persistente
python3 /opt/klawaqua/scripts/persistent_memory.py init >> $LOG 2>&1
python3 /opt/klawaqua/scripts/memory_bridge.py >> $LOG 2>&1

# 5. Log final
docker ps --format "  {{.Names}}: {{.Status}}" >> $LOG 2>&1
echo "  ✅ Ecosistema completo restaurado" >> $LOG
echo "  Modelos: $(ollama list 2>/dev/null | tail -n +2 | wc -l) disponibles" >> $LOG
echo "  Memoria: $(python3 /opt/klawaqua/scripts/persistent_memory.py stats 2>&1)" >> $LOG
