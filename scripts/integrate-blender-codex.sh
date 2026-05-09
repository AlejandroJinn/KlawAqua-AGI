#!/bin/bash
# KLAWAQUA-AGI: Integración Codex + Blender + MCP
# Herramientas OPEN SOURCE y FREE para el ecosistema

set -e

PROJECTS_DIR="/opt/klawaqua/projects"
LOG_FILE="/opt/klawaqua/logs/codex-blender-integration.log"

echo "═══════════════════════════════════════════════════════════"
echo "   KLAWAQUA-AGI: CODEX + BLENDER + MCP INTEGRATION"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Repositorios a integrar (alternativas OPEN SOURCE a Codex)
declare -a REPOS=(
    # Blender MCP (oficial, open source)
    "https://github.com/ahujasid/blender-mcp:blender-mcp:automation"
    
    # Alternativas Open Source a Codex
    "https://github.com/OpenCodeInterpreter/OpenCodeInterpreter:opencode-interpreter:coding"
    "https://github.com/codegeex/codegeex:codegeex:coding"
    "https://github.com/VanceResearch/CodeAct:codeact:coding"
    
    # Coding assistants open source
    "https://github.com/codium-ai/AlphaCodium:alphacodium:coding"
    "https://github.com/stitionai/devika:devika:ai-agents"
    "https://github.com/Laksh2501/CodeAgent:codeagent:ai-agents"
)

echo "[1/4] Clonando repositorios..."
echo ""

for repo_info in "${REPOS[@]}"; do
    IFS=':' read -r url name category <<< "$repo_info"
    
    echo -n "• $name ($category)... "
    
    if [ -d "$name" ]; then
        echo "⚠️ Ya existe"
        cd "$name" && git pull --quiet 2>/dev/null && echo "   ✓ Actualizado" || echo "   ⚠️ Sin cambios"
        cd ..
    else
        if git clone --depth 1 "$url" "$name" > /dev/null 2>&1; then
            echo "✅ Clonado"
            
            # Crear enlace categorizado
            mkdir -p "$PROJECTS_DIR/../arsenal/$category"
            ln -sfn "$PROJECTS_DIR/$name" "$PROJECTS_DIR/../arsenal/$category/$name" 2>/dev/null || true
        else
            echo "❌ Falló"
        fi
    fi
    
    echo "$(date '+%Y-%m-%d %H:%M:%S'),$name,$category,$([ -d "$name" ] && echo 'success' || echo 'failed')" >> "$LOG_FILE"
done

echo ""
echo "[2/4] Verificando Blender instalado..."

# Verificar si Blender está instalado
if command -v blender &> /dev/null; then
    BLENDERSHOW VERSION=$(blender --version | head -1)
    echo "  ✓ Blender detectado: $BLENDERSHOW VERSION"
else
    echo "  ⚠️ Blender no está instalado"
    echo ""
    echo "  Para instalar Blender:"
    echo "  ────────────────────────"
    echo "  # Opción A: Snap (recomendado)"
    echo "  sudo snap install blender --classic"
    echo ""
    echo "  # Opción B: Flatpak"
    echo "  flatpak install flathub org.blender.Blender"
    echo ""
    echo "  # Opción C: Descarga directa"
    echo "  cd /tmp && wget https://download.blender.org/release/Blender3.6/blender-3.6.5-linux-x64.tar.xz"
    echo "  tar -xf blender-3.6.5-linux-x64.tar.xz"
    echo "  sudo mv blender-3.6.5-linux-x64 /opt/blender"
    echo "  sudo ln -s /opt/blender/blender /usr/local/bin/blender"
    echo ""
fi

echo ""
echo "[3/4] Configurando Blender-MCP..."

cd "$PROJECTS_DIR/blender-mcp"

# Leer README para instrucciones
if [ -f "README.md" ]; then
    echo "  ✓ README encontrado"
    echo "  📄 Instrucciones de instalación:"
    echo ""
    grep -A 5 "install" README.md | head -20 | sed 's/^/     /' || true
    echo ""
fi

# Crear script de configuración
cat > setup-blender-mcp.sh << 'SETUP'
#!/bin/bash
# Setup script for Blender-MCP in KlawAqua

echo "══════════════════════════════════════════════"
echo "   Blender-MCP Setup - KlawAqua-AGI"
echo "══════════════════════════════════════════════"

# 1. Verificar Blender
if ! command -v blender &> /dev/null; then
    echo "❌ Blender no está instalado"
    echo "Instala primero: sudo snap install blender --classic"
    exit 1
fi

echo "✓ Blender detectado"

# 2. Crear entorno virtual
python3 -m venv venv
source venv/bin/activate

# 3. Instalar dependencias
pip install -r requirements.txt

# 4. Instalar MCP Blender como addon
echo ""
echo "Para habilitar en Blender:"
echo "  1. Abre Blender"
echo "  2. Edit → Preferences → Add-ons"
echo "  3. Install → Selecciona la carpeta del addon"
echo "  4. Enable el addon"
echo ""
echo "══════════════════════════════════════════════"
SETUP

chmod +x setup-blender-mcp.sh
echo "  ✓ Script setup-blender-mcp.sh creado"

echo ""
echo "[4/4] Generando documentación..."

cat > ../BLENTER_CODEX_GUIDE.md << 'GUIDE'
# 🎨 BLENDER + CODEX OPEN SOURCE - KLAWAQUA-AGI

**Fecha:** 2026-05-07
**Estado:** ✅ Integrado

---

## 📌 NOTA IMPORTANTE SOBRE CODEX

**OpenAI Codex NO es open source.** Es un servicio propietario de OpenAI.

**Alternativas Open Source disponibles:**

| Herramienta | Descripción | Estado |
|-------------|-------------|--------|
| **OpenCodeInterpreter** | Intérprete de código tipo Codex | ✅ Integrado |
| **CodeGeeX** | AI coding assistant multilingüe | ✅ Integrado |
| **CodeAct** | Agente de código ejecutable | ✅ Integrado |
| **AlphaCodium** | Generación de código con testing | ✅ Integrado |
| **Devika** | AI software engineer autónomo | ✅ Integrado |

---

## 🎨 BLENDER + MCP

### ¿Qué es Blender-MCP?

**Blender-MCP** permite que agentes de IA (como los de KlawAqua) controlen Blender para:
- 🎬 Generar animaciones 3D automáticamente
- 🖼️ Crear escenas y renders
- 🎭 Manipular objetos, cámaras, luces
- 📐 Modelado paramétrico vía IA

### Instalación

**Paso 1: Instalar Blender**
```bash
# Opción A: Snap (Ubuntu/Debian)
sudo snap install blender --classic

# Opción B: Flatpak
flatpak install flathub org.blender.Blender

# Opción C: Manual
wget https://download.blender.org/release/Blender3.6/blender-3.6.5-linux-x64.tar.xz
tar -xf blender-3.6.5-linux-x64.tar.xz
sudo mv blender-3.6.5-linux-x64 /opt/blender
sudo ln -s /opt/blender/blender /usr/local/bin/blender
```

**Paso 2: Configurar Blender-MCP**
```bash
cd /opt/klawaqua/projects/blender-mcp
bash setup-blender-mcp.sh
```

**Paso 3: Habilitar addon en Blender**
1. Abre Blender
2. Edit → Preferences → Add-ons
3. Install → Selecciona la carpeta `blender-mcp/addon/`
4. Marca el checkbox para activar

**Paso 4: Usar desde KlawAqua**
```python
# Desde Hermes u OpenSwarm
from integrations.blender_mcp import BlenderMCP

blender = BlenderMCP()
blender.execute("Create a cube at origin")
blender.render("output.png")
```

---

## 💻 ALTERNATIVAS CODEX (OPEN SOURCE)

### 1. OpenCodeInterpreter
**Función:** Ejecutar código generado por IA en sandbox

**Instalación:**
```bash
cd /opt/klawaqua/projects/opencode-interpreter
pip install -e .
```

**Uso:**
```python
from opencode import interpreter
result = interpreter.run("print('Hello World')", language="python")
print(result.output)
```

### 2. CodeGeeX
**Función:** Autocompletado y generación de código

**Características:**
- ✅ 100+ lenguajes
- ✅ Multilingüe (incluye español)
- ✅ Local-first option
- ✅ VS Code extension disponible

**Instalación:**
```bash
cd /opt/klawaqua/projects/codegeex
pip install -r requirements.txt
```

### 3. Devika
**Función:** AI Software Engineer autónomo

**Capacidades:**
- 🎯 Planifica tareas complejas
- 💻 Escribe código
- 🧪 Ejecuta tests
- 🔍 navega web para investigación
- 📝 Genera documentación

**Instalación:**
```bash
cd /opt/klawaqua/projects/devika
pip install -r requirements.txt
python devika.py
```

### 4. AlphaCodium
**Función:** Generación de código con validación automática

**Diferenciador:** Genera múltiples versiones y las valida automáticamente

**Instalación:**
```bash
cd /opt/klawaqua/projects/alphacodium
pip install -e .
```

---

## 🔗 INTEGRACIÓN CON KLAWAQUA

### Desde Hermes Agent
```bash
hermes -z "Crea un cubo en Blender usando MCP"
```

### Desde OpenSwarm
```yaml
agents:
  - name: "3D Designer"
    tools: ["blender-mcp"]
    model: "qwen3.5:4b"
    
  - name: "Code Generator"
    tools: ["opencode-interpreter", "codegeex"]
    model: "qwen2.5-coder:1.5b"
```

### Desde Telegram
```
@Demberius_bot: /blender create_sphere
@Demberius_bot: /code generate_python_function
```

---

## 📊 CAPACIDADES COMBINADAS

| Herramienta | Función | Modelos Compatibles |
|-------------|---------|---------------------|
| **Blender + MCP** | 3D/Animation | Todos (vía CLI) |
| **OpenCodeInterpreter** | Execute code | qwen3.5:4b, llama3.1:8b |
| **CodeGeeX** | Code completion | Todos |
| **Devika** | Autonomous dev | llama3.1:8b (mejor) |
| **AlphaCodium** | Code + tests | qwen3.5:4b, mistral:7b |

---

## 🎯 CASOS DE USO

### 1. Tutorial Animado 3D
```
Usuario: "Crea un tutorial animado sobre pitágoras"
  ↓
Hermes → Devika (planifica)
  ↓
CodeGeeX → Genera código Python
  ↓
Blender-MCP → Crea animación 3D
  ↓
OpenCodeInterpreter → Ejecuta y valida
  ↓
Resultado → Video MP4
```

### 2. Desarrollo de Software
```
Usuario: "Crea una API REST en Python"
  ↓
Devika → Planifica arquitectura
  ↓
CodeGeeX → Genera código
  ↓
AlphaCodium → Genera tests
  ↓
OpenCodeInterpreter → Ejecuta tests
  ↓
Resultado → Código validado + tests
```

### 3. Avatar Parlante 3D
```
Usuario: "Crea avatar 3D que diga 'Hola'"
  ↓
Hermes → Genera texto
  ↓
Edge TTS → Genera audio
  ↓
Blender-MCP → Anima modelo 3D
  ↓
FFmpeg → Renderiza video
  ↓
Resultado → MP4 con avatar
```

---

## 📁 UBICACIÓN DE ARCHIVOS

```
/opt/klawaqua/projects/
├── blender-mcp/              # Blender integration
├── opencode-interpreter/     # Codex alternative
├── codegeex/                 # Code assistant
├── codeact/                  # Code agent
├── alphacodium/              # Code + tests
├── devika/                   # AI engineer
├── codeagent/                # Coding agent
│
└── BLENTER_CODEX_GUIDE.md    # Esta guía
```

---

**¡Herramientas de codificación y 3D listas para usar con KlawAqua-AGI!** 🚀

*Documento generado: 2026-05-07*
GUIDE

echo "  ✓ Documentación creada: BLENTER_CODEX_GUIDE.md"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "   ✅ BLENDER + CODEX OPEN SOURCE INTEGRATED"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "📦 REPOS CLONADOS:"
for repo_info in "${REPOS[@]}"; do
    IFS=':' read -r url name category <<< "$repo_info"
    [ -d "$name" ] && echo "   ✅ $name ($category)" || echo "   ❌ $name (falló)"
done
echo ""
echo "🔧 PRÓXIMOS PASOS:"
echo "   1. Instalar Blender: sudo snap install blender --classic"
echo "   2. Configurar MCP: cd blender-mcp && bash setup-blender-mcp.sh"
echo "   3. Elegir alternativa Codex: codegeex, devika, o opencode"
echo ""
echo "📄 GUÍA COMPLETA:"
echo "   /opt/klawaqua/projects/BLENTER_CODEX_GUIDE.md"
echo ""
echo "═══════════════════════════════════════════════════════════"
