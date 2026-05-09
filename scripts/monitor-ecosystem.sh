#!/bin/bash
# KlawAqua Ecosystem Monitor
# Verifica estado de agentes, modelo local y fallback

echo "╔══════════════════════════════════════════════════╗"
echo "║     KlawAqua Ecosystem Status Monitor            ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# Check Qwen3.6
echo "📦 Modelo Principal:"
if ollama list | grep -q "qwen3.6:35b-a3b"; then
    echo "   ✅ Qwen3.6 35B-a3b: INSTALADO"
    LOCAL_MODE="active"
else
    PROGRESS=$(ps aux | grep "ollama pull" | grep -v grep | wc -l)
    if [ "$PROGRESS" -gt 0 ]; then
        echo "   ⏳ Qwen3.6 35B-a3b: DESCARGANDO..."
    else
        echo "   ❌ Qwen3.6 35B-a3b: NO INSTALADO"
    fi
    LOCAL_MODE="pending"
fi
echo ""

# Check agents
echo "🤖 Agentes Activos:"
agents=("hermes" "thepopebot" "agent" "opencode" "openhands")
for agent in "${agents[@]}"; do
    if ps aux | grep -i "$agent" | grep -v grep > /dev/null; then
        echo "   ✅ $agent: RUNNING"
    else
        echo "   ⚪ $agent: STOPPED"
    fi
done
echo ""

# Check Ollama service
echo "⚙️ Servicios Locales:"
if pgrep -x "ollama" > /dev/null; then
    echo "   ✅ Ollama: ACTIVE"
else
    echo "   ❌ Ollama: INACTIVE"
fi
echo ""

# Check OpenRouter connectivity
echo "🌐 Conectividad OpenRouter:"
if curl -s --max-time 5 https://openrouter.ai/api/v1/models > /dev/null 2>&1; then
    echo "   ✅ OpenRouter: CONNECTED"
    FREE_MODELS=$(curl -s https://openrouter.ai/api/v1/models 2>/dev/null | grep -c "free" || echo "0")
    echo "      → $FREE_MODELS modelos gratuitos disponibles"
else
    echo "   ⚠️ OpenRouter: OFFLINE (fallback no disponible)"
fi
echo ""

# Check GPU
echo "🎮 GPU Status:"
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi --query-gpu=name,memory.used,memory.free --format=csv,noheader 2>/dev/null | while read line; do
        echo "   $line"
    done
else
    echo "   ℹ️ NVIDIA GPU no detectada o nvidia-smi no disponible"
fi
echo ""

# Check auto-switch status
echo "🔄 Auto-Switch Status:"
if [ -f "/opt/klawaqua/.switched_to_local" ]; then
    SWITCH_TIME=$(cat /opt/klawaqua/.switched_to_local)
    echo "   ✅ Modo: LOCAL (desde $SWITCH_TIME)"
else
    echo "   ⏳ Modo: OPENROUTER (esperando modelo local)"
fi
echo ""

# Download progress
echo "⬇️ Download Progress (if running):"
DL_PROC=$(pgrep -f "ollama pull qwen3.6")
if [ -n "$DL_PROC" ]; then
    echo "   Process: $DL_PROC"
    echo "   Check: ps aux | grep $DL_PROC"
else
    echo "   ℹ️ No download in progress"
fi
echo ""

echo "═══════════════════════════════════════════════════"
echo "Last check: $(date)"
echo "═══════════════════════════════════════════════════"
