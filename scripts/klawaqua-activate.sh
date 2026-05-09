#!/bin/bash
# KLAWAQUA-AGI: Activar ecosistema completo con auto-recovery
# Crea compose files, arranca todos los servicios, verifica, y configura monitor
set -e

LOG="/tmp/klawaqua-activate.log"
echo "[$(date '+%H:%M:%S')] Iniciando activacion ecosistema..." > $LOG

compose_redis() {
docker compose -f /tmp/klawaqua-redis.yml up -d 2>&1 >> $LOG
}

compose_pg() {
docker compose -f /tmp/klawaqua-pg.yml up -d 2>&1 >> $LOG
}

compose_a0() {
docker compose -f /tmp/klawaqua-agent-zero.yml up -d 2>&1 >> $LOG
}

compose_oh() {
docker compose -f /tmp/klawaqua-openhands.yml up -d 2>&1 >> $LOG
}

compose_tpb() {
docker compose -f /tmp/klawaqua-thepopebot.yml up -d 2>&1 >> $LOG
}

# ============ REDIS ============
echo "[1/7] Redis..."
cat > /tmp/klawaqua-redis.yml << 'EOF'
services:
  redis:
    container_name: redis-cache
    image: redis:7-alpine
    ports:
      - "6380:6379"
    volumes:
      - redis_data:/data
    command: redis-server --appendonly yes --maxmemory 512mb --maxmemory-policy allkeys-lru
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      retries: 3
volumes:
  redis_data:
EOF

if ! redis-cli -p 6380 ping >/dev/null 2>&1; then
    docker rm -f redis-cache 2>/dev/null || true
    compose_redis
    echo "  Redis activo"
else
    echo "  Redis ya corre"
fi

# ============ POSTGRESQL ============
echo "[2/7] PostgreSQL..."
cat > /tmp/klawaqua-pg.yml << 'EOF'
services:
  postgres:
    container_name: postgres-letta
    image: postgres:15
    ports: ["5433:5432"]
    environment:
      POSTGRES_PASSWORD: klawaqua2024
      POSTGRES_DB: letta
      POSTGRES_USER: letta
    volumes: ["pg_data:/var/lib/postgresql/data"]
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U letta"]
      interval: 10s
      retries: 3
volumes:
  pg_data:
EOF

if ! pg_isready -h localhost -p 5433 >/dev/null 2>&1; then
    docker rm -f postgres-letta 2>/dev/null || true
    compose_pg
    echo "  PostgreSQL activo"
else
    echo "  PostgreSQL ya corre"
fi

# ============ AGENT ZERO ============
echo "[3/7] Agent Zero (ollama/qwen3.5:4b)..."
cat > /tmp/klawaqua-agent-zero.yml << 'EOF'
services:
  agent-zero:
    container_name: agent-zero
    image: agent0ai/agent-zero:latest
    ports: ["5080:80"]
    environment:
      LLM_PROVIDER: ollama
      LLM_DEFAULT_MODEL: qwen3.5:4b
      OLLAMA_BASE_URL: http://host.docker.internal:11434
      LLM_EMBEDDING_PROVIDER: ollama
      LLM_EMBEDDING_MODEL: all-minilm
      BRANCH: main
    extra_hosts:
      - "host.docker.internal:host-gateway"
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:80/api/health"]
      interval: 30s
      retries: 3
      start_period: 90s
EOF

docker rm -f agent-zero 2>/dev/null || true
compose_a0
echo "  Agent Zero iniciado (init tarda ~90s)"

# ============ OPENHANDS ============
echo "[4/7] OpenHands (ollama/qwen3.5:4b)..."
cat > /tmp/klawaqua-openhands.yml << 'EOF'
services:
  openhands:
    container_name: openhands-app
    image: openhands:latest
    ports: ["3000:3000"]
    environment:
      SANDBOX_RUNTIME_CONTAINER_IMAGE: docker.all-hands.dev/all-hands-ai/runtime:0.34-nikolaik
      LLM_BASE_URL: http://host.docker.internal:11434
      LLM_MODEL: ollama/qwen3.5:4b
      LLM_API_KEY: ollama
      LL_MAX_ITERATIONS: "100"
      WORKSPACE_BASE: /opt/klawaqua/projects
    extra_hosts:
      - "host.docker.internal:host-gateway"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ~/.openhands-state:/.openhands-state
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/"]
      interval: 30s
      retries: 3
      start_period: 60s
EOF

docker rm -f openhands-app 2>/dev/null || true
compose_oh
echo "  OpenHands iniciado"

# ============ THEPOPEBOT ============
echo "[5/7] ThePopeBot Event Handler..."
cat > /tmp/klawaqua-thepopebot.yml << 'EOF'
services:
  event-handler:
    container_name: thepopebot-event-handler
    image: stephengpope/thepopebot:event-handler-1.2.75
    ports: ["8080:80"]
    environment:
      AUTH_SECRET: klawaqua2026-secure-secret-abc123
      NEXTAUTH_SECRET: klawaqua2026-secure-secret-abc123
      TRAEFIK_CONFIG_DIR: /traefik-config
      LLM_BASE_URL: http://host.docker.internal:11434
      LLM_MODEL: qwen3.5:4b
    extra_hosts:
      - "host.docker.internal:host-gateway"
    volumes:
      - /opt/klawaqua/projects/thepopebot-instance:/project
      - /var/run/docker.sock:/var/run/docker.sock
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:80/api/ping"]
      interval: 10s
      retries: 3
      start_period: 60s
EOF

docker rm -f thepopebot-event-handler 2>/dev/null || true
compose_tpb
echo "  ThePopeBot iniciado"

# ============ TELEGRAM ============
echo "[6/7] Telegram Bot..."
# Limpiar todo
pkill -9 -f 'telegram-hermes-direct' 2>/dev/null || true
pkill -9 -f 'getUpdates.*telegram' 2>/dev/null || true
sleep 2

# Liberar token
curl -s -X POST "https://api.telegram.org/bot8467732148:AAFdj1GXDYFaUrIOq_ZUxp56ac0BnU17LYc/deleteWebhook?drop_pending_updates=true" >/dev/null 2>&1
sleep 3

# Limpiar offset
rm -f /tmp/telegram_hermes.log /tmp/telegram_hermes.offset
echo "0" > /tmp/telegram_hermes.offset

# Iniciar poller UNICO
TELEGRAM_BOT_TOKEN=8467732148:AAFdj1GXDYFaUrIOq_ZUxp56ac0BnU17LYc \
    bash /opt/klawaqua/scripts/telegram-hermes-direct.sh > /tmp/telegram_hermes.log 2>&1 &
TG_PID=$!
echo $TG_PID > /tmp/telegram_hermes.pid
echo "  Telegram poller iniciado PID $TG_PID"

# ============ OPENCLAW ============
echo "[7/7] OpenCLAW..."
if ! pgrep -f 'openclaw' >/dev/null 2>&1; then
    cd /opt/klawaqua/projects/openclaw 2>/dev/null || cd /home/clarwis/openclaw 2>/dev/null || true
    openclaw gateway > /tmp/openclaw-gateway.log 2>&1 &
    echo "  OpenCLAW iniciado PID $!"
else
    echo "  OpenCLAW ya corre"
fi

echo ""
echo "Activacion completa."
