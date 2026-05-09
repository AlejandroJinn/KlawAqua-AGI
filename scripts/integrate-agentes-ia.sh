#!/bin/bash
# KLAWAQUA-AGI: Integración de Agentes IA
# Adapta el repositorio Agentes_IA para usar Ollama local y conectar al ecosistema

echo "🔍 KLAWAQUA-AGI: Integrando repositorio Agentes_IA"
echo "=================================================="

AGENT_BASE="/opt/klawaqua/projects/klawaqua_agentes_ia"
OLLAMA_URL="http://localhost:11434"
DEFAULT_MODEL="qwen3.5:4b"
FALLBACK_MODEL="qwen2.5:0.5b"

echo "📁 Directorio: $AGENT_BASE"
echo "🤖 Modelo local: $DEFAULT_MODEL"
echo "🔗 Ollama URL: $OLLAMA_URL"

# Crear configuración global
echo "⚙️  Creando configuración global..."
cat > "$AGENT_BASE/.env.local" << EOF
# KLAWAQUA CONFIGURACIÓN LOCAL
OLLAMA_BASE_URL=$OLLAMA_URL
LLM_MODEL=$DEFAULT_MODEL
LLM_FALLBACK_MODEL=$FALLBACK_MODEL
LLM_PROVIDER=ollama
EMBEDDING_PROVIDER=ollama
KLAWAQUA_MODE=local-first
EOF

echo "✅ Configuración global creada"

# Adaptar cada agente para usar Ollama local
echo "🔄 Adaptando agentes para uso local..."

for agent_dir in $(find "$AGENT_BASE" -mindepth 2 -maxdepth 2 -type d); do
    if [ -f "$agent_dir/requirements.txt" ]; then
        echo "  • Adaptando: $(basename $agent_dir)"
        # Add local environment config
        cp "$AGENT_BASE/.env.local" "$agent_dir/.env.local" 2>/dev/null
        
        # Replace OpenAI/Gemini/etc references with Ollama in Python files
        for py_file in "$agent_dir"/*.py; do
            if [ -f "$py_file" ]; then
                # Add Ollama compatibility note at the top
                sed -i 's/from openai import OpenAI/### Adaptado para Ollama local\nfrom openai import OpenAI\n\nclient = OpenAI(\n    base_url="http://localhost:11434/v1",\n    api_key="ollama"\n)/g' "$py_file"
                
                # Replace model references
                sed -i 's/model="gpt-4"/model="'"$DEFAULT_MODEL"'"/g' "$py_file"
                sed -i 's/model="gpt-3.5-turbo"/model="'"$DEFAULT_MODEL"'"/g' "$py_file"
                sed -i 's/model="gemini-pro"/model="'"$DEFAULT_MODEL"'"/g' "$py_file"
            fi
        done
    fi
done

echo "✅ Agentes adaptados"

# Crear script de inicio para cada categoría
echo "📜 Creando scripts de inicio..."

cat > "$AGENT_BASE/run_starter_agents.sh" << 'EOF'
#!/bin/bash
echo "🚀 Ejecutando agentes starter..."
cd /opt/klawaqua/projects/klawaqua_agentes_ia/starter_ai_agents

for agent in */; do
    if [ -f "$agent/requirements.txt" ]; then
        echo "📦 Instalando dependencias para $agent..."
        cd "$agent"
        pip install -r requirements.txt -q
        cd ..
    fi
    if [ -f "$agent/*.py" ]; then
        echo "▶️ Ejecutando $agent"
        python3 "$agent"/*.py
    fi
done
EOF
chmod +x "$AGENT_BASE/run_starter_agents.sh"

cat > "$AGENT_BASE/run_rag_tutorials.sh" << 'EOF'
#!/bin/bash
echo "🚀 Ejecutando RAG tutorials..."
cd /opt/klawaqua/projects/klawaqua_agentes_ia/rag_tutorials

for rag in */; do
    if [ -f "$rag/requirements.txt" ]; then
        echo "📦 Instalando dependencias para $rag..."
        cd "$rag"
        pip install -r requirements.txt -q
        cd ..
    fi
    if [ -f "$rag/*.py" ]; then
        echo "▶️ Ejecutando $rag"
        python3 "$rag"/*.py
    fi
done
EOF
chmod +x "$AGENT_BASE/run_rag_tutorials.sh"

echo "✅ Scripts de inicio creados"

# Actualizar lista de repositorios del ecosistema
echo "📝 Actualizando integración con el ecosistema..."
echo "/opt/klawaqua/projects/klawaqua_agentes_ia" >> /tmp/klawaqua_repos_to_integrate.txt

echo ""
echo "🎯 INTEGRACIÓN COMPLETADA"
echo "========================="
echo "📂 Agentes integrados en: $AGENT_BASE"
echo "🔗 Configuración local: $AGENT_BASE/.env.local"
echo "📖 Para ejecutar un agente específico:"
echo "   cd /opt/klawaqua/projects/klawaqua_agentes_ia/starter_ai_agents/ai_travel_agent"
echo "   pip install -r requirements.txt"
echo "   python3 travel_agent.py"
