#!/bin/bash
# KLAWAQUA-AGI: Setup del Pipeline Avatar Parlante
# Instala todas las dependencias necesarias

set -e

echo "=================================================="
echo "   KLAWAQUA-AGI: Setup Avatar Parlante Pipeline"
echo "=================================================="
echo ""

SADTALKER_DIR="/opt/klawaqua/projects/klawaqua-avatar/SadTalker"
VENV_DIR="$SADTALKER_DIR/venv_klawaqua"

# 1. Crear virtual environment
echo "[1/4] Creando virtual environment..."
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
    echo "  ✓ Venv creado en $VENV_DIR"
else
    echo "  ✓ Venv ya existe"
fi

# 2. Activar y actualizar pip
echo ""
echo "[2/4] Actualizando pip..."
source "$VENV_DIR/bin/activate"
pip install --upgrade pip -q

# 3. Instalar PyTorch (CPU-only para compatibilidad)
echo ""
echo "[3/4] Instalando PyTorch (CPU)..."
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu -q
echo "  ✓ PyTorch instalado"

# 4. Instalar requisitos de SadTalker
echo ""
echo "[4/4] Instalando SadTalker dependencies..."
cd "$SADTALKER_DIR"

# Instalar desde requirements.txt
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt -q
    echo "  ✓ SadTalker dependencies instalados"
else
    echo "  ⚠ requirements.txt no encontrado"
fi

# Instalar additional deps
pip install edge-tts -q
echo "  ✓ edge-tts instalado"

# Desactivar venv
deactivate

echo ""
echo "=================================================="
echo "   ✅ SETUP COMPLETADO"
echo "=================================================="
echo ""
echo "Virtual environment: $VENV_DIR"
echo ""
echo "Para usar el pipeline:"
echo "  source $VENV_DIR/bin/activate"
echo "  python3 /opt/klawaqua/scripts/avatar_pipeline.py \"Hola\" output.mp4"
echo ""
echo "O ejecutar el wrapper:"
echo "  bash /opt/klawaqua/scripts/run_avatar.sh \"Hola\" output.mp4"
echo ""
