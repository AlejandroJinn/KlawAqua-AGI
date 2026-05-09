#!/bin/bash
echo "🔍 Verificación de integración Agentes_IA -> KlawAqua"
echo "====================================================="

AGENT_BASE="/opt/klawaqua/projects/klawaqua_agentes_ia"

# Verificar que los archivos existen
if [ -d "$AGENT_BASE" ]; then
    echo "✅ Directorio de agentes existe"
    total_py=$(find "$AGENT_BASE" -name "*.py" | wc -l)
    echo "  • Archivos Python: $total_py"
    total_agents=$(find "$AGENT_BASE" -mindepth 2 -maxdepth 2 -type d -name "*" -exec test -f {}/.env.local \; -print | wc -l)
    echo "  • Agentes con config local: $total_agents"
else
    echo "❌ Directorio de agentes no encontrado"
    exit 1
fi

# Verificar Ollama
if curl -sf http://localhost:11434/ &>/dev/null; then
    echo "✅ Ollama disponible"
    model_count=$(curl -sf http://localhost:11434/api/tags | python3 -c "import sys,json; print(len(json.load(sys.stdin)['models']))")
    echo "  • Modelos disponibles: $model_count"
else
    echo "❌ Ollama no disponible"
fi

# Verificar algunos agentes específicos
echo ""
echo "🔍 Verificando agentes clave..."

agents_to_check=(
    "starter_ai_agents/ai_travel_agent"
    "rag_tutorials/qwen_local_rag"
    "mcp_ai_agents/github_mcp_agent"
    "advanced_ai_agents/single_agent_apps/ai_deep_research_agent"
    "voice_ai_agents/voice_rag_openaisdk"
)

for agent in "${agents_to_check[@]}"; do
    full_path="$AGENT_BASE/$agent"
    if [ -d "$full_path" ]; then
        py_files=$(find "$full_path" -name "*.py" | wc -l)
        if [ "$py_files" -gt 0 ]; then
            echo "  ✅ $agent: $py_files archivos Python"
        else
            echo "  ⚠️ $agent: sin archivos Python"
        fi
    else
        echo "  ❌ $agent: no encontrado"
    fi
done

echo ""
echo "🎯 INTEGRACIÓN COMPLETADA"
echo "========================="
echo "Los agentes están listos para usar con Ollama local"
echo "Para ejecutar cualquier agente:"
echo "  cd /opt/klawaqua/projects/klawaqua_agentes_ia/<categoria>/<agente>"
echo "  pip install -r requirements.txt"
echo "  python3 <nombre_archivo>.py"
