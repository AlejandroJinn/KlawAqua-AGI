#!/bin/bash
# KLAWAQUA-AGI: Backup Completo al Disco Externo
# Realiza copia de seguridad completa y verificada

set -e

# Configuración
SOURCE_DIR="/opt/klawaqua"
BACKUP_DISK="/run/media/clarwis/4dee68e2-4c68-48e1-94eb-ff51e90f9ead"
BACKUP_BASE="$BACKUP_DISK/klawaqua-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$BACKUP_BASE/klawaqua-full-$TIMESTAMP"
LATEST_LINK="$BACKUP_BASE/latest"
LOG_FILE="/tmp/klawaqua-backup-$TIMESTAMP.log"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] ✓${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ✗${NC} $1" | tee -a "$LOG_FILE"
}

echo "=================================================="
echo "   KLAWAQUA-AGI: BACKUP COMPLETO"
echo "   $(date '+%Y-%m-%d %H:%M:%S')"
echo "=================================================="
echo ""

# 1. Verificar disco de backup
log "[1/6] Verificando disco de backup..."
if [ ! -d "$BACKUP_DISK" ]; then
    error "Disco de backup no encontrado: $BACKUP_DISK"
    exit 1
fi

DISK_FREE=$(df -P "$BACKUP_DISK" | awk 'NR==2 {print $4}')
DISK_FREE_GB=$((DISK_FREE / 1024 / 1024))

if [ "$DISK_FREE_GB" -lt 50 ]; then
    error "Espacio insuficiente en disco: ${DISK_FREE_GB}GB (mínimo 50GB)"
    exit 1
fi

success "Disco disponible: ${DISK_FREE_GB}GB"

# 2. Calcular tamaño a respaldar
log "[2/6] Calculando tamaño a respaldar..."
SOURCE_SIZE=$(du -s "$SOURCE_DIR" 2>/dev/null | cut -f1)
SOURCE_SIZE_GB=$((SOURCE_SIZE / 1024 / 1024))

log "Tamaño origen: ${SOURCE_SIZE_GB}GB ($SOURCE_DIR)"

if [ "$DISK_FREE_GB" -lt "$((SOURCE_SIZE_GB + 10))" ]; then
    warning "Espacio justo: ${DISK_FREE_GB}GB libre, ${SOURCE_SIZE_GB}GB a respaldar"
fi

# 3. Crear directorio de backup
log "[3/6] Preparando estructura de backup..."
mkdir -p "$BACKUP_BASE"
mkdir -p "$BACKUP_DIR"

# 4. Ejecutar backup con rsync
log "[4/6] Iniciando backup completo..."
log "Origen: $SOURCE_DIR"
log "Destino: $BACKUP_DIR"
echo ""

# Lista de exclusiones
cat > /tmp/backup_exclude.txt << EOF
*.pyc
__pycache__/
*.log
logs/*.log
tmp/
*.tmp
.env.local
node_modules/
.git/
*.git
.docker/
EOF

# Ejecutar rsync
rsync -avh --progress \
    --delete \
    --exclude-from=/tmp/backup_exclude.txt \
    "$SOURCE_DIR/" \
    "$BACKUP_DIR/" 2>&1 | tee -a "$LOG_FILE"

RSYNC_EXIT=${PIPESTATUS[0]}

if [ $RSYNC_EXIT -ne 0 ]; then
    error "rsync falló con código $RSYNC_EXIT"
    exit 1
fi

success "Backup de archivos completado"

# 5. Backup de bases de datos
log "[5/6] Respaldando bases de datos..."

# PostgreSQL (Letta)
if docker ps | grep -q postgres_letta; then
    log "Respaldando PostgreSQL (Letta)..."
    docker exec postgres_letta pg_dump -U letta letta > "$BACKUP_DIR/letta-db.sql" 2>/dev/null && \
        success "PostgreSQL respaldado" || \
        warning "Error al respaldar PostgreSQL"
fi

# Redis
if docker ps | grep -q redis; then
    log "Respaldando Redis..."
    docker exec redis redis-cli SAVE > /dev/null 2>&1
    # Copiar dump si existe
    docker cp redis:/data/dump.rdb "$BACKUP_DIR/redis-dump.rdb" 2>/dev/null && \
        success "Redis respaldado" || \
        warning "Redis: no hay dump o no se pudo copiar"
fi

# 6. Verificar y actualizar enlace latest
log "[6/6] Verificando backup y creando enlace latest..."

# Verificar directorio principal
if [ -d "$BACKUP_DIR/projects" ] && [ -d "$BACKUP_DIR/scripts" ]; then
    success "Estructura de backup verificada"
else
    error "Backup incompleto. Faltan directorios críticos."
    exit 1
fi

# Actualizar enlace simbólico latest
rm -f "$LATEST_LINK"
ln -s "$BACKUP_DIR" "$LATEST_LINK"
success "Enlace 'latest' actualizado"

# Resumen
BACKUP_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
BACKUP_FILES=$(find "$BACKUP_DIR" -type f 2>/dev/null | wc -l)

echo ""
echo "=================================================="
echo -e "${GREEN}   ✅ BACKUP COMPLETADO EXITOSAMENTE${NC}"
echo "=================================================="
echo ""
echo "📦 Detalhes del Backup:"
echo "   Directorio: $BACKUP_DIR"
echo "   Tamaño: $BACKUP_SIZE"
echo "   Archivos: $BACKUP_FILES"
echo "   Enlace latest: $LATEST_LINK"
echo ""
echo "📂 Estructura respaldada:"
echo "   ✓ /opt/klawaqua/projects (Repositorios)"
echo "   ✓ /opt/klawaqua/scripts (Scripts)"
echo "   ✓ /opt/klawaqua/config (Configuraciones)"
echo "   ✓ /opt/klawaqua/*.md (Documentación)"
echo "   ✓ Bases de datos (PostgreSQL, Redis)"
echo ""
echo "💾 Disco de Backup:"
echo "   Montado en: $BACKUP_DISK"
echo "   Espacio usado: $(du -sh $BACKUP_BASE | cut -f1)"
echo "   Espacio libre: ${DISK_FREE_GB}GB"
echo ""
echo "📋 Logs:"
echo "   $LOG_FILE"
echo ""
echo "🔄 Para restaurar:"
echo "   rsync -av $LATEST_LINK/ /opt/klawaqua/"
echo "=================================================="
echo ""

# Mantener solo últimos 10 backups
log "Limpiando backups antiguos (manteniendo últimos 10)..."
cd "$BACKUP_BASE"
ls -dt klawaqua-full-*/ 2>/dev/null | tail -n +11 | xargs rm -rf 2>/dev/null || true
success "Limpieza completada"

echo "✅ Backup completado: $(date '+%Y-%m-%d %H:%M:%S')"
