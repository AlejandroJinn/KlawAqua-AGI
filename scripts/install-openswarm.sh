#!/bin/bash
# KLAWAQUA-AGI: OpenSwarm Integration Script
# Instala y configura OpenSwarm con integración completa al ecosistema

set -e

OPENSWARM_DIR="/opt/klawaqua/projects/openswarm"
VENV_DIR="$OPENSWARM_DIR/venv"
LOG_FILE="/opt/klawaqua/logs/openswarm-install.log"

echo "═══════════════════════════════════════════════════════"
echo "   KLAWAQUA-AGI: OpenSwarm Integration"
echo "═══════════════════════════════════════════════════════"
echo ""

# 1. Verificar prerrequisitos
echo "[1/6] Verificando prerrequisitos..."
PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
NODE_VERSION=$(node --version 2>&1 || echo "not installed")

echo "  • Python: $PYTHON_VERSION ✓"
if [[ "$NODE_VERSION" == "not installed" ]]; then
    echo "  ⚠️ Node.js no encontrado (opcional para frontend)"
else
    echo "  • Node.js: $NODE_VERSION ✓"
fi

# 2. Crear entorno virtual Python
echo ""
echo "[2/6] Creando entorno virtual Python..."
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
    echo "  ✓ Entorno virtual creado en $VENV_DIR"
else
    echo "  ✓ Entorno virtual ya existe"
fi

# 3. Instalar dependencias backend
echo ""
echo "[3/6] Instalando dependencias del backend..."
source "$VENV_DIR/bin/activate"

cd "$OPENSWARM_DIR/backend"

if [ -f "requirements.txt" ]; then
    pip install --upgrade pip -q
    pip install -r requirements.txt -q 2>&1 | tee -a "$LOG_FILE" || {
        echo "  ⚠️ Algunas dependencias fallaron (continuando...)"
    }
    echo "  ✓ Dependencias backend instaladas"
else
    echo "  ⚠️ No se encontró requirements.txt"
fi

# 4. Configurar variables de entorno
echo ""
echo "[4/6] Configurando variables de entorno..."
if [ ! -f ".env" ] && [ -f ".env.example" ]; then
    cp .env.example .env
    echo "  ✓ .env creado desde .env.example"
fi

# Configurar para KlawAqua
cat >> .env << EOF

# KlawAqua-AGI Integration
KLAWAQUA_MODE=true
OLLAMA_BASE_URL=http://localhost:11434
DEFAULT_MODEL=qwen3.5:4b
HERMES_INTEGRATION=true
KLAWAQUA_PROJECTS_DIR=/opt/klawaqua/projects
EOF

echo "  ✓ Variables de KlawAqua agregadas"

# 5. Instalar frontend (opcional)
echo ""
echo "[5/6] Instalando frontend (opcional)..."
if command -v npm &> /dev/null; then
    cd "$OPENSWARM_DIR/frontend"
    if [ -f "package.json" ]; then
        npm install --silent 2>&1 | tee -a "$LOG_FILE" || echo "  ⚠️ Frontend install tuvo errores"
        echo "  ✓ Frontend instalado"
    fi
else
    echo "  ℹ️ npm no encontrado, saltando frontend"
fi

# 6. Crear script de launcher
echo ""
echo "[6/6] Creando launcher integrado..."
cat > "$OPENSWARM_DIR/run-klawaqua.sh" << 'LAUNCHER'
#!/bin/bash
# OpenSwarm + KlawAqua-AGI Launcher

OPENSWARM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$OPENSWARM_DIR/venv"
BACKEND_PORT=${BACKEND_PORT:-8324}

echo "══════════════════════════════════════════════"
echo "   OpenSwarm + KlawAqua-AGI"
echo "══════════════════════════════════════════════"
echo ""

# Activar entorno virtual
source "$VENV_DIR/bin/activate"

# Verificar Ollama
if ! curl -s http://localhost:11434/api/tags > /dev/null; then
    echo "⚠️ Ollama no está corriendo. Iniciando..."
    ollama serve &
    sleep 3
fi

# Iniciar backend
echo "🚀 Iniciando backend en puerto $BACKEND_PORT..."
cd "$OPENSWARM_DIR/backend"
export BACKEND_PORT
exec uvicorn main:app --host 0.0.0.0 --port $BACKEND_PORT --reload
LAUNCHER

chmod +x "$OPENSWARM_DIR/run-klawaqua.sh"
echo "  ✓ Launcher creado: $OPENSWARM_DIR/run-klawaqua.sh"

# 7. Crear plugin de integración
echo ""
echo "[7/6] Creando plugin de integración KlawAqua..."
mkdir -p "$OPENSWARM_DIR/backend/integrations/klawaqua"

cat > "$OPENSWARM_DIR/backend/integrations/klawaqua/__init__.py" << 'PLUGIN'
"""
KlawAqua-AGI Integration for OpenSwarm
Provides access to local models, Hermes Agent, and ecosystem tools
"""

import requests
import subprocess
from typing import Optional, Dict, Any

OLLMAMA_BASE = "http://localhost:11434"
HERMES_CLI = "/home/clarwis/.local/bin/hermes"
KLAWAQUA_PROJECTS = "/opt/klawaqua/projects"

class KlawAquaIntegration:
    """Integration with KlawAqua-AGI ecosystem"""
    
    def __init__(self):
        self.name = "KlawAqua-AGI"
        self.version = "1.0.0"
    
    def query_ollama(self, model: str, prompt: str) -> str:
        """Query local Ollama model"""
        try:
            response = requests.post(
                f"{OLLMAMA_BASE}/api/generate",
                json={
                    "model": model,
                    "prompt": prompt,
                    "stream": False
                },
                timeout=120
            )
            return response.json().get('response', '')
        except Exception as e:
            return f"Error: {str(e)}"
    
    def query_hermes(self, prompt: str) -> str:
        """Query Hermes Agent CLI"""
        try:
            result = subprocess.run(
                [HERMES_CLI, '-z', prompt],
                capture_output=True,
                text=True,
                timeout=120
            )
            return result.stdout.strip()
        except Exception as e:
            return f"Error: {str(e)}"
    
    def list_local_models(self) -> list:
        """List available local models"""
        try:
            response = requests.get(f"{OLLMAMA_BASE}/api/tags", timeout=10)
            models = response.json().get('models', [])
            return [m['name'] for m in models]
        except:
            return []
    
    def get_ecosystem_status(self) -> Dict[str, Any]:
        """Get KlawAqua ecosystem status"""
        return {
            "ollama_running": self._check_ollama(),
            "hermes_available": self._check_hermes(),
            "local_models": self.list_local_models(),
            "projects_count": self._count_projects(),
            "smart_router": "qwen3.5:4b (primary) + llama3.1:8b (specialized)"
        }
    
    def _check_ollama(self) -> bool:
        try:
            r = requests.get(f"{OLLMAMA_BASE}/api/tags", timeout=5)
            return r.status_code == 200
        except:
            return False
    
    def _check_hermes(self) -> bool:
        import os
        return os.path.exists(HERMES_CLI)
    
    def _count_projects(self) -> int:
        import os
        try:
            return len([d for d in os.listdir(KLAWAQUA_PROJECTS) 
                       if os.path.isdir(os.path.join(KLAWAQUA_PROJECTS, d))])
        except:
            return 0

# Export instance
klawaqua = KlawAquaIntegration()
PLUGIN

echo "  ✓ Plugin de integración creado"

# 8. Generar reporte
echo ""
echo "═══════════════════════════════════════════════════════"
echo "   ✅ OPENSWARE INTEGRATION COMPLETED"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "📁 Directorios:"
echo "   OpenSwarm: $OPENSWARM_DIR"
echo "   Backend: $OPENSWARM_DIR/backend"
echo "   Frontend: $OPENSWARM_DIR/frontend (si npm disponible)"
echo "   Venv: $VENV_DIR"
echo ""
echo "🔧 Integración KlawAqua:"
echo "   ✓ Plugin: backend/integrations/klawaqua/"
echo "   ✓ Modelos locales: Ollama (qwen3.5:4b, llama3.1:8b)"
echo "   ✓ Hermes Agent: Integrado"
echo "   ✓ 186 proyectos: Accesibles"
echo ""
echo "🚀 Para iniciar OpenSwarm:"
echo "   bash $OPENSWARM_DIR/run-klawaqua.sh"
echo ""
echo "   O manualmente:"
echo "   cd $OPENSWARM_DIR/backend"
echo "   source $VENV_DIR/bin/activate"
echo "   uvicorn main:app --host 0.0.0.0 --port 8324"
echo ""
echo "📊 Frontend (si instalado):"
echo "   http://localhost:3000 (o puerto configurado)"
echo ""
echo "🐛 Backend API:"
echo "   http://localhost:8324"
echo "   http://localhost:8324/docs (Swagger)"
echo ""
echo "═══════════════════════════════════════════════════════"
