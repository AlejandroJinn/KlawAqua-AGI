#!/bin/bash
# GitNexus Setup para KlawAqua-AGI
# Configuración rápida de GitNexus para gestión de repositorios GitHub

set -e

echo "=================================================="
echo "   GitNexus Setup - KlawAqua-AGI"
echo "=================================================="
echo ""

GITNEXUS_DIR="/opt/klawaqua/projects/GitNexus"
ENV_FILE="$GITNEXUS_DIR/.env"

# Verificar que GitNexus existe
if [ ! -d "$GITNEXUS_DIR" ]; then
    echo "❌ GitNexus no encontrado en $GITNEXUS_DIR"
    echo "Ejecutando clone..."
    cd /opt/klawaqua/projects
    git clone --depth 1 https://github.com/abhigyanpatwari/GitNexus.git
fi

cd "$GITNEXUS_DIR"

echo "✓ GitNexus encontrado"
echo ""

# Crear .env desde ejemplo
if [ ! -f "$ENV_FILE" ] && [ -f "$GITNEXUS_DIR/.env.example" ]; then
    echo "Creando .env desde plantilla..."
    cp "$GITNEXUS_DIR/.env.example" "$ENV_FILE"
    echo "✓ .env creado"
else
    echo "⚠ .env ya existe o no hay plantilla"
fi

# Instrucciones para el usuario
echo ""
echo "=================================================="
echo "   CONFIGURACIÓN REQUERIDA"
echo "=================================================="
echo ""
echo "Para completar la configuración de GitNexus, necesitas:"
echo ""
echo "1. Generar un GitHub Personal Access Token:"
echo "   → https://github.com/settings/tokens/new"
echo "   Scopes necesarios: repo, read:user, user:email"
echo ""
echo "2. Editar el archivo .env:"
echo "   nano $ENV_FILE"
echo ""
echo "3. Agregar tu token:"
echo "   GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx"
echo ""
echo "4. (Opcional) Configurar organización:"
echo "   GITHUB_ORG=klawaqua"
echo ""
echo "=================================================="
echo "   COMANDOS ÚTILES"
echo "=================================================="
echo ""
echo "Iniciar GitNexus:"
echo "  cd $GITNEXUS_DIR && npm start"
echo ""
echo "Analizar repositorios:"
echo "  npx gitnexus analyze"
echo ""
echo "Listar repos indexados:"
echo "  npx gitnexus list-repos"
echo ""
echo "Consultar código:"
echo "  npx gitnexus query 'auth validation'"
echo ""
echo "Análisis de impacto:"
echo "  npx gitnexus impact --target functionName"
echo ""
echo "=================================================="
echo ""
echo "una vez configurado, GitNexus permitirá:"
echo "  ✓ Gestión centralizada de todos los repos KlawAqua"
echo "  ✓ Búsqueda semántica de código en todo el ecosistema"
echo "  ✓ Análisis de impacto antes de editar"
echo "  ✓ Detección automática de cambios"
echo "  ✓ Rename seguro de símbolos multi-archivo"
echo "  ✓ Cross-repo impact analysis"
echo ""
echo "=================================================="
