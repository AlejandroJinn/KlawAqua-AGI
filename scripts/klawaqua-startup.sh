     1|#!/bin/bash
     2|# ========================================================================
     3|# KLAWAQUA-AGI: STARTUP ORCHESTRATOR
     4|# Local-first, cloud-fallback, auto-recovery, resource-optimized
     5|# Inicia TODO el ecosistema KlawAqua de forma limpia y eficiente
     6|# ========================================================================
     7|
     8|set -e
     9|
    10|KLAWAQUA_DIR="/opt/klawaqua"
    11|COMPOSE_FILE="$KLAWAQUA_DIR/klawaqua-docker-compose.yml"
    12|LOG_FILE="/tmp/klawaqua-startup.log"
    13|PIDFILE="$KLAWAQUA_DIR/.ecosystem.pid"
    14|
    15|# Colores (solo para terminal, no afecta logica)
    16|GREEN="\033[0;32m"
    17|YELLOW="\033[1;33m"
    18|RED="\033[0;31m"
    19|NC="\033[0m"
    20|
    21|log() {
    22|    echo -e "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"
    23|}
    24|
    25|# ========================================================================
    26|# FASE 0: LIMPIEZA PRE-ACTIVACION
    27|# ========================================================================
    28|log "═══════════════════════════════════════════════"
    29|log "  KLAWAQUA-AGI: ECOSYSTEM STARTUP"
    30|log "  Local-First Sovereign AI System"
    31|log "═══════════════════════════════════════════════"
    32|
    33|# Limpiar Telegram pollers conflictivos
    34|log "${YELLOW}[0/6] Limpiando estados previos...${NC}"
    35|pkill -9 -f 'telegram-hermes-direct' 2>/dev/null || true
    36|pkill -9 -f 'telegram-hermes-manager' 2>/dev/null || true
    37|pkill -9 -f 'merlyn_bot.py' 2>/dev/null || true
    38|sleep 1
    39|
    40|# Liberar token Telegram
    41|curl -s -X POST "https://api.telegram.org/bot8467732148:AAFdj1GXDYFaUrIOq_ZUxp56ac0BnU17LYc/deleteWebhook?drop_pending_updates=true" > /dev/null 2>&1
    42|sleep 2
    43|log "  Pollers limpios, token liberado"
    44|
    45|# ========================================================================
    46|# FASE 1: VERIFICAR RECURSOS
    47|# ========================================================================
    48|log "${YELLOW}[1/6] Verificando recursos...${NC}"
    49|
    50|# Verificar VRAM
    51|VRAM_USED=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader 2>/dev/null | tr -d "MiB " | head -1)
    52|VRAM_USED_NUM=${VRAM_USED:-0}; VRAM_AVAIL=$((6141 - VRAM_USED_NUM))
    53|log "  VRAM usada: ${VRAM_USED_NUM}MiB | disponible: ${VRAM_AVAIL}MiB"
    54|
    55|# Verificar RAM
    56|RAM_AVAIL=$(free -m | awk '/Mem:/ {print $7}')
    57|log "  RAM disponible: ${RAM_AVAIL}MB"
    58|
    59|# Verificar disco
    60|DISK_AVAIL=$(df -m / | awk 'NR==2 {print $4}')
    61|log "  Disco disponible: ${DISK_AVAIL}MB"
    62|log "  Recursos OK"
    63|
    64|# ========================================================================
    65|# FASE 2: OLLAMA
    66|# ========================================================================
    67|log "${YELLOW}[2/6] Iniciando Ollama...${NC}"
    68|
    69|if systemctl is-active --quiet ollama; then
    70|    log "  Ollama ya corriendo"
    71|else
    72|    systemctl start ollama
    73|    sleep 2
    74|    log "  Ollama iniciado via systemctl"
    75|fi
    76|
    77|# Verificar que Ollama responde
    78|if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    79|    MODELS=$(ollama list --format json 2>/dev/null | head -20 || echo "modelos disponibles")
    80|    log "  Ollama activo en localhost:11434"
    81|else
    82|    log "${RED}  ERROR: Ollama no responde${NC}"
    83|fi
    84|
    85|# ========================================================================
    86|# FASE 3: DOCKER + COMPOSE
    87|# ========================================================================
    88|log "${YELLOW}[3/6] Iniciando contenedores Docker...${NC}"
    89|
    90|if [ -f "$COMPOSE_FILE" ]; then
    91|    # Asegurar que OpenHands tenga imagen (si no usa build en lugar)
    92|    if docker images --format "{{.Repository}}" | grep -q "^openhands$"; then
    93|        log "  OpenHands image found"
    94|    fi
    95|
    96|    # Iniciar compose
    97|    cd /opt/klawaqua
    98|    docker compose -f klawaqua-docker-compose.yml up -d --remove-orphans 2>&1 | tee -a "$LOG_FILE"
    99|
   100|    sleep 5
   101|
   102|    # Verificar contenedores
   103|    log "  Contenedores activos:"
   104|    COMPOSE_NAMES=$(docker compose -f klawaqua-docker-compose.yml ps --format '{{.Name}} : {{.Status}}' 2>/dev/null)
   105|    if [ -n "$COMPOSE_NAMES" ]; then
   106|        echo "$COMPOSE_NAMES" | while read line; do
   107|            log "    $line"
   108|        done
   109|    fi
   110|else
   111|    log "  Starting individual containers as fallback..."
   112|    
   113|    # Agent Zero con Ollama
   114|    if ! docker ps --format '{{.Names}}' | grep -q "^agent-zero$"; then
   115|        docker run -d --name agent-zero \
   116|            -p 5080:80 \
   117|            -e LLM_PROVIDER=ollama \
   118|            -e LLM_DEFAULT_MODEL=qwen3.5:4b \
   119|            -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
   120|            --add-host=host.docker.internal:host-gateway \
   121|            --restart unless-stopped \
   122|            agent0ai/agent-zero:latest 2>/dev/null
   123|        log "    Agent Zero started (localhost:5080)"
   124|    fi
   125|
   126|    # Redis
   127|    if ! docker ps --format '{{.Names}}' | grep -q "^redis-cache$"; then
   128|        docker run -d --name redis-cache \
   129|            -p 6380:6379 \
   130|            --restart unless-stopped \
   131|            redis:7-alpine \
   132|            redis-server --appendonly yes --maxmemory 512mb --maxmemory-policy allkeys-lru 2>/dev/null
   133|        log "    Redis started (localhost:6380)"
   134|    fi
   135|
   136|    # Postgres
   137|    if ! docker ps --format '{{.Names}}' | grep -q "^postgres-letta$"; then
   138|        docker run -d --name postgres-letta \
   139|            -p 5433:5432 \
   140|            -e POSTGRES_PASSWORD=klawaqua2024 \
   141|            -e POSTGRES_DB=letta \
   142|            -e POSTGRES_USER=letta \
   143|            --restart unless-stopped \
   144|            -v postgres_data:/var/lib/postgresql/data \
   145|            postgres:15 2>/dev/null
   146|        log "    PostgreSQL started (localhost:5433)"
   147|    fi
   148|
   149|    # ThePopeBot
   150|    if ! docker ps --format '{{.Names}}' | grep -q "thepopebot"; then
   151|        cd /opt/klawaqua/projects/thepopebot-instance
   152|        docker compose up -d 2>/dev/null
   153|        log "    ThePopeBot instance restored"
   154|    fi
   155|
   156|    # LiteLLM
   157|    if ! docker ps --format '{{.Names}}' | grep -q "litellm"; then
   158|        docker run -d --name litellm-proxy \
   159|            --network host \
   160|            -e OPENROUTER_API_KEY=$(grep OPENROUTER_API_KEY /home/clarwis/.hermes/.env 2>/dev/null | cut -d= -f2) \
   161|            -v /opt/klawaqua/projects/thepopebot-instance/event-handler/litellm:/litellm:ro \
   162|            --restart unless-stopped \
   163|            ghcr.io/berriai/litellm:main-latest \
   164|            --config /litellm/main.yaml --port 4000 2>/dev/null
   165|        log "    LiteLLM Proxy started (localhost:4000)"
   166|    fi
   167|fi
   168|
   169|# ========================================================================
   170|# FASE 4: OPENCLAW GATEWAY
   171|# ========================================================================
   172|log "${YELLOW}[4/6] Verificando OpenCLAW...${NC}"
   173|
   174|if pgrep -f "openclaw" > /dev/null 2>&1; then
   175|    log "  OpenCLAW ya corriendo (localhost:18789)"
   176|else
   177|    cd /opt/klawaqua/projects/openclaw 2>/dev/null || cd /home/clarwis/openclaw 2>/dev/null || true
   178|    if command -v openclaw > /dev/null 2>&1; then
   179|        openclaw gateway > /tmp/openclaw-gateway.log 2>&1 &
   180|        sleep 3
   181|        if pgrep -f "openclaw" > /dev/null 2>&1; then
   182|            log "  OpenCLAW iniciado (localhost:18789)"
   183|        else
   184|            log "  WARNING: OpenCLAW no pudo iniciar"
   185|        fi
   186|    else
   187|        log "  WARNING: openclaw command not found"
   188|    fi
   189|fi
   190|
   191|# ========================================================================
   192|# FASE 5: TELEGRAM BOT (UNICO POLLER)
   193|# ========================================================================
   194|log "${YELLOW}[5/6] Iniciando Telegram Bot...${NC}"
   195|
   196|# Verificar que no hay poller activo antes de iniciar
   197|if pgrep -f 'telegram-hermes-direct' > /dev/null 2>&1 || pgrep -f 'merlyn_bot' > /dev/null 2>&1; then
   198|    log "  Telegram bot ya activo"
   199|else
   200|    # Unico script de poller - sin duplicados
   201|    if [ -f "$KLAWAQUA_DIR/scripts/telegram-hermes-direct.sh" ]; then
   202|        TELEGRAM_BOT_TOKEN=8467732148:AAFdj1GXDYFaUrIOq_ZUxp56ac0BnU17LYc \
   203|            nohup bash "$KLAWAQUA_DIR/scripts/telegram-hermes-direct.sh" > /tmp/telegram_hermes.log 2>&1 &
   204|        echo $! > /tmp/telegram_hermes.pid
   205|        
   206|        # Esperar que el poller se registre
   207|        sleep 3
   208|        
   209|        # Verificar que no da error 409
   210|        if [ -f /tmp/telegram_hermes.log ]; then
   211|            if grep -q "409\|Conflict" /tmp/telegram_hermes.log; then
   212|                log "  WARNING: Conflicto Telegram, liberando token..."
   213|                pkill -9 -f 'telegram-hermes-direct' 2>/dev/null || true
   214|                sleep 3
   215|                curl -s -X POST "https://api.telegram.org/bot8467732148:AAFdj1GXDYFaUrIOq_ZUxp56ac0BnU17LYc/deleteWebhook?drop_pending_updates=true" > /dev/null 2>&1
   216|                sleep 2
   217|                TELEGRAM_BOT_TOKEN=8467732148:AAFdj1GXDYFaUrIOq_ZUxp56ac0BnU17LYc \
   218|                    nohup bash "$KLAWAQUA_DIR/scripts/telegram-hermes-direct.sh" > /tmp/telegram_hermes.log 2>&1 &
   219|                echo $! > /tmp/telegram_hermes.pid
   220|                sleep 2
   221|            fi
   222|        fi
   223|        
   224|        if pgrep -f 'telegram-hermes-direct' > /dev/null 2>&1; then
   225|            log "  Telegram Bot activo (@Demberius_bot)"
   226|        else
   227|            log "  WARNING: Telegram bot no pudo iniciar"
   228|        fi
   229|    else
   230|        log "  WARNING: telegram-hermes-direct.sh no encontrado"
   231|    fi
   232|fi
   233|
   234|# ========================================================================
   235|# FASE 6: HERMES GATEWAY
   236|# ========================================================================
   237|log "${YELLOW}[6/6] Verificando Hermes Gateway...${NC}"
   238|
   239|if pgrep -f "hermes_cli.main gateway" > /dev/null 2>&1; then
   240|    log "  Hermes Gateway ya corriendo"
   241|else
   242|    log "  Hermes Gateway no esta activo (ejecuta Hermes CLI para iniciar)"
   243|fi
   244|
   245|# ========================================================================
   246|# VERIFICACION FINAL
   247|# ========================================================================
   248|sleep 8
   249|
   250|log ""
   251|log "═══════════════════════════════════════════════"
   252|log "  SERVICIOS ACTIVOS"
   253|log "═══════════════════════════════════════════════"
   254|
   255|SERVICES=("Agent Zero:localhost:5080" "OpenHands:localhost:3000" "ThePopeBot:localhost:8080" "LiteLLM:localhost:4000" "OpenCLAW:localhost:18789" "Ollama:localhost:11434")
   256|
   257|for svc in "${SERVICES[@]}"; do
   258|    NAME="${svc%%:*}"
   259|    PORT="${svc##*:}"
   260|    if curl -s -o /dev/null -w "%{http_code}" "http://$PORT" 2>/dev/null | grep -q "200\|404\|302"; then
   261|        log "  ${GREEN}✅ $NAME${NC} :$PORT"
   262|    else
   263|        STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$PORT" 2>/dev/null || echo "000")
   264|        if [ "$STATUS" != "000" ]; then
   265|            log "  ${YELLOW}⚠️ $NAME${NC} :$PORT (HTTP $STATUS)"
   266|        else
   267|            log "  ${RED}❌ $NAME${NC} :$PORT"
   268|        fi
   269|    fi
   270|done
   271|
   272|# Redis y Postgres
   273|redis-cli -p 6380 ping > /dev/null 2>&1 && log "  ${GREEN}✅ Redis${NC} :6380" || log "  ${RED}❌ Redis${NC} :6380"
   274|pg_isready -h localhost -p 5433 > /dev/null 2>&1 && log "  ${GREEN}✅ PostgreSQL${NC} :5433" || log "  ${RED}❌ PostgreSQL${NC} :5433"
   275|
   276|# Telegram
   277|pgrep -f 'telegram-hermes-direct' > /dev/null 2>&1 && log "  ${GREEN}✅ Telegram Bot${NC} (@Demberius_bot)" || log "  ${RED}❌ Telegram Bot${NC}"
   278|
   279|log ""
   280|log "═══════════════════════════════════════════════"
   281|log "  RECURSOS ACTUALES"
   282|log "═══════════════════════════════════════════════"
   283|
   284|VRAM_USED=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader 2>/dev/null | tr -d "MiB " | head -1)
   285|log "  VRAM: ${VRAM_USED:-0}MiB / 6141MiB"
   286|RAM_USED=$(free -m | awk '/Mem:/ {print $3}')
   287|RAM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
   288|log "  RAM: ${RAM_USED}MB / ${RAM_TOTAL}MB"
   289|LOAD=$(uptime | awk -F'load average:' '{print $2}' | xargs)
   290|log "  Load: $LOAD"
   291|
   292|log ""
   293|log "  MODELOS OLLAMA:"
   294|ollama list 2>/dev/null | tail -n +2 | awk '{printf "    • %s (%s)\n", $1, $3}'
   295|
   296|log ""
   297|log "═══════════════════════════════════════════════"
   298|log "  ✅ KLAWAQUA-AGI ECOSYSTEM READY"
   299|log "  Local-First | Cloud-Fallback | Auto-Recovery"
   300|log "═══════════════════════════════════════════════"
   301|