#!/bin/bash
# KlawAqua Agent Configuration Script
# Configura todos los agentes con Qwen3.6 35B + OpenRouter Fallback

set -e

echo "=========================================="
echo "KlawAqua Multi-Agent Configuration"
echo "Modelo: Qwen3.6 35B-a3b (Local + Fallback)"
echo "=========================================="
echo ""

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Funciones
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar si Qwen3.6 está descargado
check_model() {
    echo "Verificando modelo Qwen3.6 35B..."
    if ollama list | grep -q "qwen3.6:35b-a3b"; then
        log_info "Qwen3.6 35B-a3b está instalado"
        return 0
    else
        log_warn "Qwen3.6 35B-a3b no está instalado aún"
        echo "La descarga está en progreso. Este script continuará pero algunos agentes usarán fallback."
        return 1
    fi
}

# Configurar Hermes Agent
configure_hermes() {
    echo ""
    echo "Configurando Hermes Agent..."
    
    if command -v hermes &> /dev/null; then
        hermes config set main_model qwen3.6:35b-a3b 2>/dev/null || log_warn "Hermes no pudo configurar main_model"
        hermes config set fallback_provider openrouter 2>/dev/null || log_warn "Hermes no pudo configurar fallback"
        log_info "Hermes configurado"
    else
        log_warn "Hermes CLI no encontrado, configurando manualmente..."
        cat > /home/clarwis/.hermes/config.yaml << EOF
main_model: qwen3.6:35b-a3b
fallback_provider: openrouter
local_first: true
ollama_base_url: http://localhost:11434
EOF
        log_info "Hermes config creado manualmente"
    fi
}

# Configurar ThePopeBot
configure_thepopebot() {
    echo ""
    echo "Configurando ThePopeBot..."
    
    THEPOPEBOT_CONFIG="/opt/klawaqua/thepopebot/config.yaml"
    if [ -f "$THEPOPEBOT_CONFIG" ]; then
        # Backup
        cp "$THEPOPEBOT_CONFIG" "${THEPOPEBOT_CONFIG}.bak"
    fi
    
    cat > "$THEPOPEBOT_CONFIG" << EOF
model: qwen3.6:35b-a3b
fallback: openrouter-free
never_disconnect: true
ollama_base_url: http://localhost:11434
openrouter_models:
  - kilo/nvidia/nemotron-3-super-120b-a12b:free
  - kilo/poolside/laguna-m.1:free
  - kilo/inclusionai/ling-2.6-1t:free
routing:
  investigacion: Agent_Zero
  codigo: Opencode
  avatar: Avatar_System
  general: local
EOF
    log_info "ThePopeBot configurado"
}

# Configurar Agent Zero
configure_agent_zero() {
    echo ""
    echo "Configurando Agent Zero..."
    
    AGENT_ZERO_ENV="/opt/klawaqua/projects/agent-zero/.env"
    if [ -f "$AGENT_ZERO_ENV" ]; then
        # Backup
        cp "$AGENT_ZERO_ENV" "${AGENT_ZERO_ENV}.bak"
        # Agregar/actualizar variables
        sed -i '/PRIMARY_MODEL=/d' "$AGENT_ZERO_ENV"
        sed -i '/FALLBACK_PROVIDER=/d' "$AGENT_ZERO_ENV"
    fi
    
    cat >> "$AGENT_ZERO_ENV" << EOF
PRIMARY_MODEL=qwen3.6:35b-a3b
OLLAMA_BASE_URL=http://localhost:11434
FALLBACK_PROVIDER=openrouter
OPENROUTER_MODELS_FREE=kilo/nvidia/nemotron-3-super-120b-a12b:free
ENABLE_LOCAL_LLM=true
EOF
    log_info "Agent Zero configurado"
}

# Configurar Opencode
configure_opencode() {
    echo ""
    echo "Configurando Opencode..."
    
    OPENCODE_CONFIG="$HOME/.config/opencode/config.yaml"
    mkdir -p "$(dirname "$OPENCODE_CONFIG")"
    
    cat > "$OPENCODE_CONFIG" << EOF
default_model: qwen3.6:35b-a3b
fallback_provider: openrouter
models:
  coding: qwen3.6:35b-a3b
  review: qwen3:4b
  general: qwen3.6:35b-a3b
openrouter:
  free_models:
    - kilo/poolside/laguna-m.1:free
    - kilo/x-ai/grok-code-fast-1:optimized:free
EOF
    log_info "Opencode configurado"
}

# Configurar OpenClaude
configure_openclaude() {
    echo ""
    echo "Configurando OpenClaude..."
    
    OPENCLAUDE_CONFIG="/opt/klawaqua/openclaude/config.yaml"
    if [ -f "$OPENCLAUDE_CONFIG" ]; then
        cp "$OPENCLAUDE_CONFIG" "${OPENCLAUDE_CONFIG}.bak"
    fi
    
    cat > "$OPENCLAUDE_CONFIG" << EOF
providers:
  local:
    type: ollama
    model: qwen3.6:35b-a3b
    base_url: http://localhost:11434
  fallback:
    type: openrouter
    models:
      - kilo/nvidia/nemotron-3-super-120b-a12b:free
      - kilo/tencent/hy3-preview:free
routing:
  default: local
  backup: fallback
EOF
    log_info "OpenClaude configurado"
}

# Configurar OpenHands
configure_openhands() {
    echo ""
    echo "Configurando OpenHands..."
    
    OPENHANDS_CONFIG="/opt/klawaqua/OpenHands/config.toml"
    if [ -f "$OPENHANDS_CONFIG" ]; then
        cp "$OPENHANDS_CONFIG" "${OPENHANDS_CONFIG}.bak"
    fi
    
    cat >> "$OPENHANDS_CONFIG" << EOF

# KlawAqua Configuration
[llm]
model = "ollama/qwen3.6:35b-a3b"
base_url = "http://localhost:11434"
fallback_models = [
  "openrouter/kilo/nvidia/nemotron-3-super-120b-a12b:free",
  "openrouter/kilo/poolside/laguna-m.1:free"
]
EOF
    log_info "OpenHands configurado"
}

# Verificar estado de agentes
verify_agents() {
    echo ""
    echo "Verificando estado de agentes..."
    
    agents=("hermes" "thepopebot" "agent-zero" "opencode" "openhands")
    
    for agent in "${agents[@]}"; do
        if ps aux | grep -i "$agent" | grep -v grep > /dev/null; then
            log_info "$agent: Activo"
        else
            log_warn "$agent: No ejecutándose"
        fi
    done
}

# Main
echo "Iniciando configuración..."
echo ""

check_model
configure_hermes
configure_thepopebot
configure_agent_zero
configure_opencode
configure_openclaude
configure_openhands
verify_agents

echo ""
echo "=========================================="
echo "Configuración Completada"
echo "=========================================="
echo ""
echo "Próximos pasos:"
echo "1. Esperar descarga completa de Qwen3.6 35B"
echo "2. Reiniciar agentes si es necesario"
echo "3. Probar con: /opt/klawaqua/scripts/test-qwen36.sh"
echo ""
echo "Logs en: /opt/klawaqua/logs/"
echo "Config en: /opt/klawaqua/config/multi-agent-config.yaml"
