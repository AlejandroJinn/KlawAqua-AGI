#!/bin/bash
# KLAWAQUA-AGI: Instalador Completo de Newelle + Extensiones
# Instala Newelle con TODAS las extensiones disponibles

set -e

NEWELLE_DIR="/opt/klawaqua/projects/Newelle"
EXTENSIONS_DIR="/opt/klawaqua/projects/Newelle-Extensions"
PLUGIN_DIR="$NEWELLE_DIR/plugins"

echo "═══════════════════════════════════════════════════════════"
echo "   KLAWAQUA-AGI: Newelle + Extensiones Installer"
echo "═══════════════════════════════════════════════════════════"
echo ""

# 1. Verificar Newelle
if [ ! -d "$NEWELLE_DIR" ]; then
    echo "[1/5] Clone Newelle..."
    cd /opt/klawaqua/projects
    git clone --depth 1 https://github.com/qwersyk/Newelle.git
else
    echo "[1/5] ✅ Newelle ya existe"
fi

# 2. Crear directorio de extensiones
echo ""
echo "[2/5] Preparando directorio de extensiones..."
mkdir -p "$EXTENSIONS_DIR"
mkdir -p "$PLUGIN_DIR"

# Lista de extensiones importantes
declare -a EXTENSIONS=(
    "FrancescoCaracciolo/Newelle-LLMS"
    "FrancescoCaracciolo/Newelle-Image-Generator"
    "FrancescoCaracciolo/Newelle-Coding"
    "FrancescoCaracciolo/Newelle-Planning"
    "FrancescoCaracciolo/Newelle-Advanced-Tools"
    "FrancescoCaracciolo/AI-WebNavigator"
    "hurryman2212/Newelle-Gemini-Webapi"
    "Max-Blade/extensions-for-newelle"
)

# 3. Clonar extensiones
echo ""
echo "[3/5] Clonando ${#EXTENSIONS[@]} extensiones..."
for ext in "${EXTENSIONS[@]}"; do
    ext_name=$(basename "$ext")
    echo "  → $ext_name..."
    cd "$EXTENSIONS_DIR"
    if [ ! -d "$ext_name" ]; then
        git clone --depth 1 "https://github.com/$ext.git" 2>/dev/null || echo "    ⚠️ Falló $ext_name"
    else
        echo "    ✅ Ya existe"
    fi
done

# 4. Copiar plugins a Newelle
echo ""
echo "[4/5] Instalando plugins en Newelle..."
for ext in "${EXTENSIONS[@]}"; do
    ext_name=$(basename "$ext")
    ext_path="$EXTENSIONS_DIR/$ext_name"
    
    if [ -d "$ext_path" ]; then
        # Buscar archivos .py o carpetas de plugins
        find "$ext_path" -name "*.py" -o -name "plugin.json" | while read file; do
            plugin_dir=$(dirname "$file")
            # Copiar si es un plugin válido
            if [ -f "$plugin_dir/plugin.json" ] || [[ "$file" == *.py ]]; then
                cp -r "$plugin_dir" "$PLUGIN_DIR/" 2>/dev/null || true
            fi
        done
        echo "  ✅ $ext_name instalado"
    fi
done

# 5. Configurar Ollama
echo ""
echo "[5/5] Configurando conexión con Ollama..."

# Crear config de Ollama para Newelle
cat > "$NEWELLE_DIR/ollama-config.json" << 'EOF'
{
    "provider": "ollama",
    "base_url": "http://localhost:11434",
    "models": [
        {
            "name": "qwen3.5:4b",
            "default": true,
            "context_size": 128000
        },
        {
            "name": "mistral:7b",
            "default": false,
            "context_size": 32000
        },
        {
            "name": "llama3.2:3b",
            "default": false,
            "context_size": 8000
        }
    ]
}
EOF

echo "  ✅ Config Ollama creada: $NEWELLE_DIR/ollama-config.json"

# Mostrar resumen
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "   ✅ INSTALACIÓN COMPLETADA"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "📁 Directorios:"
echo "   Newelle: $NEWELLE_DIR"
echo "   Extensiones: $EXTENSIONS_DIR"
echo "   Plugins: $PLUGIN_DIR"
echo ""
echo "🔧 Extensiones instaladas: ${#EXTENSIONS[@]}"
for ext in "${EXTENSIONS[@]}"; do
    echo "   • $(basename $ext)"
done
echo ""
echo "💾 Modelos Ollama configurados:"
echo "   • qwen3.5:4b (principal)"
echo "   • mistral:7b"
echo "   • llama3.2:3b"
echo ""
echo "🚀 Para ejecutar Newelle:"
echo "   cd $NEWELLE_DIR"
echo "   python3 src/main.py"
echo ""
echo "   O crear launcher:"
echo "   bash $NEWELLE_DIR/create-launcher.sh"
echo ""
echo "═══════════════════════════════════════════════════════════"
