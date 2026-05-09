#!/bin/bash
# KlawAqua-AGI System Auditor
# Auditoría completa del ecosistema y detección de faltantes

echo "=================================================="
echo "   KLAWAQUA-AGI SYSTEM AUDITOR"
echo "   Plataforma Operativa Local de IA"
echo "=================================================="
echo ""

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Contadores
TOTAL_CHECKS=0
PASSED=0
FAILED=0
WARNINGS=0

check() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
        PASSED=$((PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $2"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

warn() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    echo -e "${YELLOW}⚠${NC} $1"
    WARNINGS=$((WARNINGS + 1))
}

section() {
    echo ""
    echo -e "${BLUE}==================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}==================================================${NC}"
}

# 1. HARDWARE Y RECURSOS
section "1. HARDWARE Y RECURSOS"

# GPU
nvidia-smi --query-gpu=name,memory.total,memory.used,memory.free --format=csv,noheader,nounits 2>/dev/null | while read name total used free; do
    echo "GPU: $name"
    echo "  VRAM Total: ${total}MB"
    echo "  VRAM Usada: ${used}MB"
    echo "  VRAM Libre: ${free}MB"
done

# RAM
free -h | awk '/^Mem:/ {print "RAM Total: "$2"\nRAM Usada: "$3"\nRAM Libre: "$4}'

# Disco
df -h /opt/klawaqua 2>/dev/null | awk 'NR==2 {print "Disco /opt/klawaqua:\n  Total: "$2"\n  Usado: "$3"\n  Libre: "$4}'

# 2. MODELOS OLLAMA
section "2. MODELOS OLLAMA"

echo "Modelos instalados:"
ollama list 2>/dev/null || echo "Error: Ollama no está corriendo"

# Modelos recomendados
echo ""
echo "Modelos recomendados para KlawAqua-AGI:"
declare -A RECOMMENDED_MODELS=(
    ["qwen3.5:4b"]="Modelo principal - 2.5GB"
    ["qwen3:4b"]="Alternativo - 2.5GB"
    ["qwen2.5:7b"]="Tareas complejas - 4.7GB"
    ["mistral:7b"]="Backup - 4.4GB"
    ["qwen2.5-coder:1.5b"]="Código rápido - 986MB"
    ["qwen2.5:0.5b"]="Tareas simples - 397MB"
)

for model in "${!RECOMMENDED_MODELS[@]}"; do
    if ollama list 2>/dev/null | grep -q "^$model"; then
        echo -e "${GREEN}✓${NC} $model (${RECOMMENDED_MODELS[$model]})"
    else
        echo -e "${YELLOW}○${NC} $model (${RECOMMENDED_MODELS[$model]}) - FALTA"
    fi
done

# 3. SERVICIOS DOCKER
section "3. SERVICIOS DOCKER"

docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "Error: Docker no está corriendo"

# Servicios críticos
echo ""
echo "Servicios críticos:"
declare -a CRITICAL_SERVICES=("agent-zero" "openhands" "thepopebot" "litellm" "redis" "postgres")

for service in "${CRITICAL_SERVICES[@]}"; do
    if docker ps 2>/dev/null | grep -q "$service"; then
        echo -e "${GREEN}✓${NC} $service"
    else
        echo -e "${RED}✗${NC} $service - INACTIVO"
    fi
done

# 4. AGENTES DE IA
section "4. AGENTES DE IA"

# Hermes Agent
echo "Hermes Agent:"
if command -v hermes &> /dev/null; then
    echo -e "${GREEN}✓${NC} Instalado"
    if pgrep -f "hermes.*gateway" > /dev/null; then
        echo -e "${GREEN}✓${NC} Gateway corriendo"
    else
        echo -e "${YELLOW}⚠${NC} Gateway no está corriendo"
    fi
else
    echo -e "${RED}✗${NC} No instalado"
fi

# Agent Zero
echo ""
echo "Agent Zero:"
if docker ps 2>/dev/null | grep -q "agent-zero"; then
    echo -e "${GREEN}✓${NC} Docker container activo"
    if curl -s http://localhost:5080/api/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} API responding (puerto 5080)"
    else
        echo -e "${YELLOW}⚠${NC} API no responde"
    fi
else
    echo -e "${RED}✗${NC} No está corriendo"
fi

# OpenHands
echo ""
echo "OpenHands:"
if docker ps 2>/dev/null | grep -q "openhands"; then
    echo -e "${GREEN}✓${NC} Docker container activo"
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 2>/dev/null | grep -q "200"; then
        echo -e "${GREEN}✓${NC} UI responding (puerto 3000)"
    else
        echo -e "${YELLOW}⚠${NC} UI no responde"
    fi
else
    echo -e "${RED}✗${NC} No está corriendo"
fi

# OpenCLAW
echo ""
echo "OpenCLAW:"
if pgrep -f openclaw > /dev/null; then
    echo -e "${GREEN}✓${NC} Gateway corriendo"
    if openclaw gateway status 2>/dev/null | grep -q "running"; then
        echo -e "${GREEN}✓${NC} Estado: activo"
    fi
else
    echo -e "${RED}✗${NC} No está corriendo"
fi

# ThePopeBot
echo ""
echo "ThePopeBot:"
if [ -d "/opt/klawaqua/thepopebot" ]; then
    echo -e "${GREEN}✓${NC} Instalado"
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 2>/dev/null | grep -q "404\|200"; then
        echo -e "${GREEN}✓${NC} Event Handler responding (puerto 8080)"
    else
        echo -e "${YELLOW}⚠${NC} Event Handler no responde"
    fi
else
    echo -e "${RED}✗${NC} No instalado"
fi

# 5. REPOSITORIOS
section "5. REPOSITORIOS"

REPO_COUNT=$(ls /opt/klawaqua/projects/ 2>/dev/null | wc -l)
echo "Total de repositorios en /opt/klawaqua/projects/: $REPO_COUNT"

echo ""
echo "Repositorios críticos:"
declare -a CRITICAL_REPOS=("agent-zero" "opencode" "OpenHands" "openclaude" "thepopebot" "GitNexus")

for repo in "${CRITICAL_REPOS[@]}"; do
    if [ -d "/opt/klawaqua/projects/$repo" ]; then
        echo -e "${GREEN}✓${NC} $repo"
    else
        echo -e "${RED}✗${NC} $repo - FALTA"
    fi
done

# 6. CONFIGURACIONES
section "6. CONFIGURACIONES"

# Verificar configs
declare -A CONFIG_FILES=(
    ["/home/clarwis/.hermes/config.yaml"]="Hermes Agent"
    ["/home/clarwis/.openclaw/openclaw.json"]="OpenCLAW"
    ["/opt/klawaqua/thepopebot/config.yaml"]="ThePopeBot"
    ["/opt/klawaqua/OpenHands/config.toml"]="OpenHands"
    ["/home/clarwis/.config/opencode/config.yaml"]="Opencode"
    ["/opt/klawaqua/openclaude/config.yaml"]="OpenClaude"
)

for config in "${!CONFIG_FILES[@]}"; do
    if [ -f "$config" ]; then
        if grep -q "qwen3.5:4b" "$config" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} ${CONFIG_FILES[$config]} (configurado con qwen3.5:4b)"
        else
            echo -e "${YELLOW}⚠${NC} ${CONFIG_FILES[$config]} (revisar configuración)"
        fi
    else
        echo -e "${RED}✗${NC} ${CONFIG_FILES[$config]} - NO EXISTE"
    fi
done

# 7. LITELLM PROXY
section "7. LITELLM PROXY"

if [ -f "/opt/klawaqua/projects/thepopebot-instance/event-handler/litellm/main.yaml" ]; then
    echo -e "${GREEN}✓${NC} Configuración LiteLLM existe"
    MODEL_COUNT=$(grep -c "model_name:" /opt/klawaqua/projects/thepopebot-instance/event-handler/litellm/main.yaml 2>/dev/null || echo "0")
    echo "  Modelos configurados: $MODEL_COUNT"
else
    echo -e "${RED}✗${NC} Configuración LiteLLM no existe"
fi

# 8. RESUMEN
section "8. RESUMEN DE AUDITORÍA"

echo "Total de checks: $TOTAL_CHECKS"
echo -e "${GREEN}Superados: $PASSED${NC}"
echo -e "${RED}Fallidos: $FAILED${NC}"
echo -e "${YELLOW}Advertencias: $WARNINGS${NC}"

echo ""
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ SISTEMA OPERATIVO - Todos los componentes críticos activos${NC}"
else
    echo -e "${RED}✗ ATENCIÓN - $FAILED componentes críticos requieren atención${NC}"
fi

echo ""
echo "=================================================="
echo "Generado: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=================================================="
