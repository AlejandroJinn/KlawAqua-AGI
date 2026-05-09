#!/bin/bash
# KLAWAQUA-AGI: ECOSYSTEM STARTUP SCRIPT
# Invocable desde Hermes CLI: hermes skill run klawaqua-start
# O directamente: bash /opt/klawaqua/scripts/klawaqua-start.sh

set -e

echo "═══════════════════════════════════════════════════════"
echo "   🚀 KLAWAQUA-AGI: INICIANDO ECOSISTEMA COMPLETO"
echo "   Local-First Sovereign AI System"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "[📊 ESTADO INICIAL]"
echo "──────────────────────────────────────────────────────"

# Función para verificar servicio
check_service() {
    local name=$1
    local check=$2
    
    if eval "$check" > /dev/null 2>&1; then
        echo "  ✅ $name"
        return 0
    else
        echo "  ❌ $name"
        return 1
    fi
}

# Verificar servicios
check_service "Ollama" "curl -s http://localhost:11434/api/tags"
check_service "Docker" "docker ps"

echo ""
echo "[🔄 INICIANDO SERVICIOS]"
echo "──────────────────────────────────────────────────────"

# 1. Verificar Docker
if ! docker ps > /dev/null 2>&1; then
    echo "⚠️ Docker no está corriendo. Iniciando..."
    sudo systemctl start docker 2>/dev/null || echo "  ⚠️ Inicia Docker manualmente: sudo systemctl start docker"
fi

# 2. Verificar Ollama
if ! curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "⚠️ Ollama no está corriendo. Iniciando..."
    sudo systemctl start ollama 2>/dev/null || ollama serve &
    sleep 5
fi

# 3. Iniciar contenedores Docker
echo ""
echo "Iniciando contenedores Docker..."
echo ""

# Agent Zero
if docker ps --format '{{.Names}}' | grep -q "^agent-zero$"; then
    docker start agent-zero > /dev/null 2>&1 && echo "  ✅ Agent Zero (localhost:5080)"
else
    echo "  ⚠️ Agent Zero no está configurado"
fi

# OpenHands
if docker ps --format '{{.Names}}' | grep -q "^openhands-app"; then
    docker start openhands-app- > /dev/null 2>&1 && echo "  ✅ OpenHands (localhost:3000)"
else
    echo "  ⚠️ OpenHands no está configurado"
fi

# LiteLLM
if docker ps --format '{{.Names}}' | grep -q "litellm"; then
    docker start thepopebot-instance-litellm-1 > /dev/null 2>&1 && echo "  ✅ LiteLLM Proxy (localhost:4000)"
else
    echo "  ⚠️ LiteLLM no está configurado"
fi

# ThePopeBot Event Handler
if docker ps --format '{{.Names}}' | grep -q "thepopebot-event"; then
    docker start thepopebot-event-handler > /dev/null 2>&1 && echo "  ✅ ThePopeBot Event Handler (localhost:8080)"
else
    echo "  ⚠️ ThePopeBot no está configurado"
fi

# Redis
if docker ps --format '{{.Names}}' | grep -q "^redis$"; then
    docker start redis > /dev/null 2>&1 && echo "  ✅ Redis Cache (localhost:6380)"
else
    echo "  ⚠️ Redis no está configurado"
fi

# Postgres
if docker ps --format '{{.Names}}' | grep -q "postgres"; then
    docker start postgres_letta > /dev/null 2>&1 && echo "  ✅ PostgreSQL (localhost:5433)"
else
    echo "  ⚠️ PostgreSQL no está configurado"
fi

# 4. Iniciar OpenCLAW Gateway
echo ""
echo "Iniciando servicios locales..."
if pgrep -f "openclaw" > /dev/null; then
    echo "  ✅ OpenCLAW Gateway (localhost:18789) - Ya corriendo"
else
    cd /home/clarwis/openclaw && nohup bash -c 'exec openclaw gateway' > /tmp/gateway.log 2>&1 &
    sleep 3
    if pgrep -f "openclaw" > /dev/null; then
        echo "  ✅ OpenCLAW Gateway (localhost:18789) - Iniciado"
    else
        echo "  ⚠️ OpenCLAW Gateway - Error al iniciar"
    fi
fi

# 5. Iniciar Telegram Bot (Merlyn)
if pgrep -f "merlyn_bot" > /dev/null; then
    echo "  ✅ Telegram Bot (@Demberius_bot) - Ya corriendo"
else
    echo "  ℹ️ Telegram Bot - Para iniciar: python3 /opt/klawaqua/scripts/merlyn_bot_direct.py &"
fi

# 6. Iniciar Hermes Gateway (si no está)
if pgrep -f "hermes_cli.main gateway" > /dev/null; then
    echo "  ✅ Hermes Gateway - Ya corriendo"
else
    echo "  ℹ️ Hermes Gateway - Para iniciar: hermes gateway run"
fi

# 7. Verificar modelos Ollama
echo ""
echo "Verificando modelos Ollama..."
ollama list 2>/dev/null | grep -E "qwen3.5|mistral|llama3" | awk '{print "  ✅ " $1 " (" $3 ")"}' || echo "  ⚠️ Ollama no responde"

# Resumen final
echo ""
echo "═══════════════════════════════════════════════════════"
echo "   📊 RESUMEN DEL ECOSISTEMA"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "🌐 PUNTOS DE ACCESO:"
echo "   • Agent Zero:     http://localhost:5080"
echo "   • OpenHands:      http://localhost:3000"
echo "   • ThePopeBot:     http://localhost:8080"
echo "   • OpenCLAW:       http://localhost:18789"
echo "   • LiteLLM Proxy:  http://localhost:4000"
echo "   • Ollama API:     http://localhost:11434"
echo ""
echo "📱 COMUNICACIÓN:"
echo "   • Telegram Bot:   @Demberius_bot"
echo "   • Hermes CLI:     hermes -z \"tu consulta\""
echo ""
echo "💾 MODELOS LOCALES:"
ollama list 2>/dev/null | awk 'NR>1 {print "   • " $1}'
echo ""
echo "🔒 FILOSOFÍA:"
echo "   • 100% LOCAL (€0/mes)"
echo "   • Privacidad: 100%"
echo "   • Sin dependencias cloud"
echo "   • Soberanía total"
echo ""
echo "═══════════════════════════════════════════════════════"
echo "   ✅ KLAWAQUA-AGI ECOSYSTEM READY"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "💡 COMANDOS ÚTILES:"
echo "   • hermes -z \"Hola\"                → Usar Hermes CLI"
echo "   • curl localhost:5080/api/health  → Ver Agent Zero"
echo "   • docker ps                       → Ver contenedores"
echo "   • bash /opt/klawaqua/scripts/klawaqua-stop.sh   → Apagar"
echo ""
