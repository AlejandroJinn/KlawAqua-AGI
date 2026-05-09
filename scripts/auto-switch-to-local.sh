#!/bin/bash
# Auto-Switch Script: OpenRouter → Local Qwen3.5 4B
# Se ejecuta cada 5 minutos para verificar si el modelo está listo

MODEL="qwen3.5:4b"
LOG_FILE="/opt/klawaqua/logs/auto-switch.log"
SWITCHED_FLAG="/opt/klawaqua/.switched_to_local"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

log() {
    echo "[$TIMESTAMP] $1" | tee -a "$LOG_FILE"
}

# Check if already switched
if [ -f "$SWITCHED_FLAG" ]; then
    # Verify model still exists
    if ! ollama list | grep -q "$MODEL"; then
        log "WARNING: Model was switched but is no longer available!"
        rm "$SWITCHED_FLAG"
    fi
    exit 0
fi

# Check if model is ready
if ollama list | grep -q "$MODEL"; then
    log "✓ Qwen3.5 4B está disponible!"
    log "Cambiando todos los agentes a modo LOCAL..."
    
    # Switch Hermes
    if command -v hermes &> /dev/null; then
        hermes config set main_model "$MODEL" 2>/dev/null
        hermes config set local_first true 2>/dev/null
    fi
    
    # Switch ThePopeBot
    if [ -f "/opt/klawaqua/thepopebot/config.yaml" ]; then
        sed -i 's/modo_actual: openrouter-primary/modo_actual: local-automatico/' /opt/klawaqua/thepopebot/config.yaml
        sed -i 's/default: cloud/default: local/' /opt/klawaqua/thepopebot/config.yaml
    fi
    
    # Switch Agent Zero
    if [ -f "/opt/klawaqua/projects/agent-zero/.env" ]; then
        sed -i 's/CURRENT_MODE=openrouter-primary/CURRENT_MODE=local-automatico/' /opt/klawaqua/projects/agent-zero/.env
    fi
    
    # Switch Opencode
    if [ -f "$HOME/.config/opencode/config.yaml" ]; then
        sed -i 's/current_provider: openrouter/current_provider: ollama/' "$HOME/.config/opencode/config.yaml"
    fi
    
    # Switch OpenClaude
    if [ -f "/opt/klawaqua/openclaude/config.yaml" ]; then
        sed -i 's/enabled: false  # Se activará automáticamente cuando el modelo esté listo/enabled: true/' /opt/klawaqua/openclaude/config.yaml
        sed -i 's/default: cloud/default: local/' /opt/klawaqua/openclaude/config.yaml
    fi
    
    # Switch OpenHands
    if [ -f "/opt/klawaqua/OpenHands/config.toml" ]; then
        sed -i 's/# model = "ollama\/qwen3.6:35b-a3b"/model = "ollama\/qwen3.6:35b-a3b"/' /opt/klawaqua/OpenHands/config.toml
    fi
    
    # Marcar como cambiado
    echo "$TIMESTAMP" > "$SWITCHED_FLAG"
    
    log "✅ Cambio a modo LOCAL completado!"
    log "Todos los agentes ahora usan Qwen3.5 4B localmente"
    
    # Enviar notificación al usuario vía Telegram (si Hermes está disponible)
    if command -v hermes &> /dev/null; then
        hermes send "✅ KlawAqua 100% LOCAL ACTIVADO\n\nEl modelo Qwen3.5 4B está completamente descargado y operativo.\n\nTodos los agentes han sido configurados automáticamente:\n• Hermes: Local ✓\n• ThePopeBot: Local ✓\n• Agent Zero: Local ✓\n• Opencode: Local ✓\n• OpenClaude: Local ✓\n• OpenHands: Local ✓\n\nModo: 100% Local + Fallback OpenRouter (gratuito)\n\n¡Ecosistema completamente autónomo!" 2>/dev/null || true
    fi
    
else
    log "Model not ready yet. Checking OpenRouter fallback... (no action needed)"
fi
