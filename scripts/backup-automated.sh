#!/bin/bash
# KLAWAQUA-AGI: BACKUP AUTOMATICO COMPLETO
# Uso: bash /opt/klawaqua/scripts/backup-automated.sh [destino]
# Destino por defecto: /opt/klawaqua/backups/ (o disco externo si esta montado)

set -e

BACKUP_DEST="${1:-/opt/klawaqua/backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$BACKUP_DEST/klawaqua_backup_$TIMESTAMP"
KLAWAQUA_ROOT="/opt/klawaqua"

echo "======================================="
echo "  KLAWAQUA-AGI BACKUP AUTOMATICO"
echo "  $(date)"
echo "  Destino: $BACKUP_DEST"
echo "======================================="

# Crear directorio
mkdir -p "$BACKUP_DIR"

# Funcion para respaldar con excluciones inteligentes
backup_with_exclude() {
    local src=$1
    local dest=$2
    local name=$3
    shift 3
    local excludes=("$@")
    
    echo "  Respaldando $name..."
    exclude_args=()
    for excl in "${excludes[@]}"; do
        exclude_args+=(--exclude="$excl")
    done
    
    rsync -a --info=progress2 "${exclude_args[@]}" "$src" "$dest" 2>/dev/null ||     rsync -a "${exclude_args[@]}" "$src" "$dest"
    echo "  ✅ $name listo"
}

# 1. BACKUP SCRIPTS (critico, pequeno)
echo ""
echo "[1/7] Scripts..."
mkdir -p "$BACKUP_DIR/scripts"
rsync -a /opt/klawaqua/scripts/ "$BACKUP_DIR/scripts/"

# 2. BACKUP CONFIGURACIONES
echo "[2/7] Configuraciones..."
mkdir -p "$BACKUP_DIR/config"
cp -r ~/.hermes/config.yaml "$BACKUP_DIR/config/" 2>/dev/null || true
cp -r ~/.openclaw/openclaw.json "$BACKUP_DIR/config/" 2>/dev/null || true
cp -r /opt/klawaqua/thepopebot/config.yaml "$BACKUP_DIR/config/" 2>/dev/null || true
find /opt/klawaqua/projects/thepopebot-instance/event-handler/litellm/ -name "*.yaml" -exec cp {} "$BACKUP_DIR/config/" \; 2>/dev/null || true

# 3. BACKUP PROJECTS (excluyendo node_modules, .git, venv, __pycache__)
echo "[3/7] Proyectos..."
mkdir -p "$BACKUP_DIR/projects"
backup_with_exclude     /opt/klawaqua/projects/     "$BACKUP_DIR/projects/"     "Proyectos"     "*/node_modules/*" "*/.git/*" "*/.venv/*" "*/venv/*" "*/__pycache__/*"     "*/.persist/*" "*/.cache/*" "*/dist/*" "*/build/*"

# 4. BACKUP MODELOS (solo configs, no binarios - esos se pull de ollama)
echo "[4/7] Modelos configs..."
mkdir -p "$BACKUP_DIR/models"
ls /opt/klawaqua/models/ 2>/dev/null && cp -r /opt/klawaqua/models/ "$BACKUP_DIR/models/" || true

# 5. BACKUP HERMES HOME
echo "[5/7] Hermes home..."
mkdir -p "$BACKUP_DIR/hermes_home"
backup_with_exclude     /opt/klawaqua/hermes_home/     "$BACKUP_DIR/hermes_home/"     "Hermes"     "*/node_modules/*" "*/__pycache__/*" "*/.cache/*"

# 6. BACKUP DOCKER CONFIGS
echo "[6/7] Docker configs..."
mkdir -p "$BACKUP_DIR/docker"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" > "$BACKUP_DIR/docker/containers_status.txt" 2>/dev/null
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" > "$BACKUP_DIR/docker/images_status.txt" 2>/dev/null
# Save docker-compose files
find /opt/klawaqua/projects/thepopebot-instance/ -name "docker-compose*.yml" -exec cp {} "$BACKUP_DIR/docker/" \; 2>/dev/null || true

# 7. BACKUP ESTADO DEL SISTEMA
echo "[7/7] Estado del sistema..."
mkdir -p "$BACKUP_DIR/system"
ollama list > "$BACKUP_DIR/system/ollama_models.txt" 2>/dev/null
nvidia-smi > "$BACKUP_DIR/system/gpu_status.txt" 2>/dev/null
free -h > "$BACKUP_DIR/system/memory.txt" 2>/dev/null
df -h > "$BACKUP_DIR/system/disk.txt" 2>/dev/null

# Generar resumen
echo ""
echo "======================================="
echo "  RESUMEN DEL BACKUP"
echo "======================================="
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
echo "Tamanio total: $TOTAL_SIZE"
echo "Ubicacion: $BACKUP_DIR"

# Generar lista de archivos
find "$BACKUP_DIR" -type f | wc -l > "$BACKUP_DIR/file_count.txt"
FILE_COUNT=$(cat "$BACKUP_DIR/file_count.txt")
echo "Archivos: $FILE_COUNT"

# Crear timestamp
date '+%Y-%m-%d %H:%M:%S' > "$BACKUP_DIR/.backup_timestamp"

echo ""
echo "✅ BACKUP COMPLETADO"
echo "======================================="
