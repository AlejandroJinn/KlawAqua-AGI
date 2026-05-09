#!/bin/bash
# KLAWAQUA-AGI: Integración Arsenal 2 (Video Adicional)
# Clona 20 repositorios adicionales mencionados en video

set -e

PROJECTS_DIR="/opt/klawaqua/projects"
LOG_FILE="/opt/klawaqua/logs/arsenal2-integration.log"

echo "═══════════════════════════════════════════════════════════"
echo "   KLAWAQUA-AGI: ARSENAL FASE 2 (20 REPOS ADICIONALES)"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Lista de repositorios (URLs corregidas)
declare -a REPOS=(
    "https://github.com/mksglu/context-mode"
    "https://github.com/deepseek-ai/DeepGEMM"
    "https://github.com/luongnv89/claude-howto"
    "https://github.com/siddharthvaddem/openscreen"
    "https://github.com/HKUDS/DeepTutor"
    "https://github.com/microsoft/markitdown"
    "https://github.com/google-ai-edge/LiteRT-LM"
    "https://github.com/google-research/timesfm"
    "https://github.com/rtk-ai/rtk"
    "https://github.com/cmc-labo/tinyos-rtos"
    "https://github.com/razvandimescu/numa"
    "https://github.com/marimo-team/marimo-pair"
    "https://github.com/brightbeanxyz/brightbean-studio"
    "https://github.com/final-run/finalrun-agent"
    "https://github.com/multigres/multigres-operator"
    "https://github.com/RyanCodrai/turbovec"
    "https://github.com/patoles/agent-flow"
    "https://github.com/zolotukhin/zinc"
    "https://github.com/neo4j-labs/create-context-graph"
    "https://github.com/larksuite/cli"
)

# Categorías
declare -A CATEGORIES=(
    ["context-mode"]="ai-tools"
    ["DeepGEMM"]="ml-optimization"
    ["claude-howto"]="documentation"
    ["openscreen"]="screen-sharing"
    ["DeepTutor"]="education"
    ["markitdown"]="documents"
    ["LiteRT-LM"]="ml-inference"
    ["timesfm"]="time-series"
    ["rtk"]="ai-tools"
    ["/tinyos-rtos"]="embedded"
    ["numa"]="system-tools"
    ["marimo-pair"]="data-science"
    ["brightbean-studio"]="creative"
    ["finalrun-agent"]="ai-agents"
    ["multigres-operator"]="ml-ops"
    ["turbovec"]="ml-optimization"
    ["agent-flow"]="automation"
    ["zinc"]="storage"
    ["create-context-graph"]="knowledge-graph"
    ["cli"]="productivity"
)

cd "$PROJECTS_DIR"

TOTAL=${#REPOS[@]}
SUCCESS=0
FAILED=0
ALREADY_EXISTS=0

echo "[1/3] Clonando $TOTAL repositorios..."
echo ""

for i in "${!REPOS[@]}"; do
    repo_url="${REPOS[$i]}"
    repo_name=$(basename "$repo_url" .git)
    category="${CATEGORIES[$repo_name]:-general}"
    
    echo -n "[$((i+1))/$TOTAL] $repo_name ($category)... "
    
    if [ -d "$repo_name" ] || [ -L "$repo_name" ]; then
        echo "⚠️ Ya existe"
        ((ALREADY_EXISTS++))
        SUCCESS=$((SUCCESS + 1))
    else
        if git clone --depth 1 "$repo_url" "$repo_name" > /dev/null 2>&1; then
            echo "✅ Clonado"
            
            # Crear enlaces categorizados
            mkdir -p "$PROJECTS_DIR/../arsenal/$category"
            ln -sfn "$PROJECTS_DIR/$repo_name" "$PROJECTS_DIR/../arsenal/$category/$repo_name" 2>/dev/null || true
            
            ((SUCCESS++))
        else
            echo "❌ Falló"
            ((FAILED++))
        fi
    fi
    
    echo "$(date '+%Y-%m-%d %H:%M:%S'),$repo_name,$category,$([ -d "$repo_name" ] && echo 'success' || echo 'failed')" >> "$LOG_FILE"
done

echo ""
echo "[2/3] Actualizando estructura categorizada..."

# Crear nuevas categorías
mkdir -p "$PROJECTS_DIR/../arsenal/{ml-optimization,ml-inference,ml-ops,documentation,education,screen-sharing,time-series,embedded,system-tools,data-science,creative,ai-agents,knowledge-graph}"

echo ""
echo "[3/3] Generando índice actualizado..."

# Contar repos por categoría
echo "📊 ARSENAL KLAWAQUA - REPOSITORIOS POR CATEGORÍA" > /tmp/arsenal_summary.txt
echo "═══════════════════════════════════════════════════════" >> /tmp/arsenal_summary.txt
echo "" >> /tmp/arsenal_summary.txt

for category in ai-tools automation media-server data-indexing documents infrastructure coding storage networking communication filesystem database productivity ml-optimization ml-inference ml-ops documentation education screen-sharing time-series embedded system-tools data-science creative ai-agents knowledge-graph; do
    count=$(ls -la "$PROJECTS_DIR/../arsenal/$category/" 2>/dev/null | grep -c "^l" || echo "0")
    if [ "$count" -gt 0 ]; then
        echo "  $category: $count repositorios" >> /tmp/arsenal_summary.txt
    fi
done

# Crear índice completo
cat > "$PROJECTS_DIR/../ARSENAL_COMPLETE_INDEX.md" << EOF
# 🎯 KLAWAQUA ARSENAL COMPLETO

**Fecha:** $(date '+%Y-%m-%d %H:%M:%S')
**Fase 1:** 20 repositorios (video herramientas IA)
**Fase 2:** 20 repositorios (video adicional)
**Total General:** ~$(ls -d $PROJECTS_DIR/*/ 2>/dev/null | wc -l) repositorios

---

$(cat /tmp/arsenal_summary.txt)

---

## 📁 REPOSITORIOS FASE 2 (NUEVOS)

| Repositorio | Categoría | Estado |
|-------------|-----------|--------|
EOF

for repo_url in "${REPOS[@]}"; do
    repo_name=$(basename "$repo_url" .git)
    category="${CATEGORIES[$repo_name]:-general}"
    status=$([ -d "$repo_name" ] && echo "✅" || echo "❌")
    echo "| $repo_name | $category | $status |" >> "$PROJECTS_DIR/../ARSENAL_COMPLETE_INDEX.md"
done

cat >> "$PROJECTS_DIR/../ARSENAL_COMPLETE_INDEX.md" << EOF

---

## 🚀 PRÓXIMOS PASOS

1. **Instalar dependencias** de cada repositorio según sea necesario
2. **Configurar integraciones** con el ecosistema existente
3. **Documentar** casos de uso específicos
4. **Automatizar** actualizaciones periódicas

---

**Ubicación:** /opt/klawaqua/projects/
**Índice categorizado:** /opt/klawaqua/arsenal/
**Documentación:** /opt/klawaqua/ARSENAL_COMPLETE_INDEX.md

EOF

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "   ✅ INTEGRACIÓN FASE 2 COMPLETADA"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "📊 RESULTADOS:"
echo "   ✅ Exitosos: $SUCCESS"
echo "   ❌ Fallidos: $FAILED"
echo "   ⚠️ Ya existían: $ALREADY_EXISTS"
echo "   📁 Total: $TOTAL"
echo ""
echo "📂 UBICACIÓN:"
echo "   Principal: $PROJECTS_DIR/"
echo "   Categorizado: $PROJECTS_DIR/../arsenal/"
echo ""
echo "📄 DOCUMENTACIÓN:"
echo "   /opt/klawaqua/ARSENAL_COMPLETE_INDEX.md"
echo ""
echo "📋 NUEVAS CATEGORÍAS:"
echo "   • ml-optimization (DeepGEMM, turbovec)"
echo "   • ml-inference (LiteRT-LM)"
echo "   • ml-ops (Multigres Operator)"
echo "   • documentation (claude-howto)"
echo "   • education (DeepTutor)"
echo "   • screen-sharing (openscreen)"
echo "   • time-series (timesfm)"
echo "   • embedded (TinyOS)"
echo "   • system-tools (numa)"
echo "   • data-science (marimo-pair)"
echo "   • creative (BrightBean Studio)"
echo "   • ai-agents (finalrun-agent)"
echo "   • knowledge-graph (create-context-graph)"
echo ""
echo "═══════════════════════════════════════════════════════════"
