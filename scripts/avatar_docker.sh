#!/bin/bash
# KLAWAQUA-AGI: Generar Avatar con Docker SadTalker
# No requiere instalación local de PyTorch

set -e

KLAWAQUA_BASE="/opt/klawaqua"
SADTALKER_IMAGE="ghcr.io/sdtalkers/sadtalker:latest"
WORKDIR="/workspace"

echo "=================================================="
echo "   KLAWAQUA-AGI: Avatar con Docker SadTalker"
echo "=================================================="
echo ""

# Parse argumentos
if [ $# -lt 2 ]; then
    echo "Uso: $0 <audio.wav> <imagen.png> [output.mp4]"
    echo ""
    echo "Ejemplo:"
    echo "  $0 /tmp/audio.wav avatar.png /tmp/video.mp4"
    exit 1
fi

AUDIO_FILE="$1"
IMAGE_FILE="$2"
OUTPUT_FILE="${3:-output.mp4}"

# Verificar archivos
if [ ! -f "$AUDIO_FILE" ]; then
    echo "❌ Audio no encontrado: $AUDIO_FILE"
    exit 1
fi

if [ ! -f "$IMAGE_FILE" ]; then
    echo "❌ Imagen no encontrada: $IMAGE_FILE"
    exit 1
fi

# Convertir a paths absolutos
AUDIO_FILE=$(realpath "$AUDIO_FILE")
IMAGE_FILE=$(realpath "$IMAGE_FILE")
OUTPUT_FILE=$(realpath "$OUTPUT_FILE")

echo "Audio: $AUDIO_FILE"
echo "Imagen: $IMAGE_FILE"
echo "Output: $OUTPUT_FILE"
echo ""

# Crear directorio temporal para results
TMPDIR=$(mktemp -d)
echo "Directorio temporal: $TMPDIR"

# Ejecutar SadTalker en Docker
echo ""
echo "Ejecutando SadTalker en Docker..."
docker run --rm \
  -v "$KLAWAQUA_BASE:$WORKDIR" \
  -v "$TMPDIR:/results" \
  "$SADTALKER_IMAGE" \
  python3 inference.py \
    --driven_audio "$WORKDIR/$(basename $AUDIO_FILE)" \
    --source_image "$WORKDIR/$(basename $IMAGE_FILE)" \
    --result_dir /results \
    --checkpoint_dir "$WORKDIR/projects/klawaqua-avatar/SadTalker/checkpoints" \
    --preprocess crop \
    --size 256 \
    --still \
    --expr_coeff 3.0 \
    --pose_coeff 1.5 \
    2>&1 | tail -20

# Buscar video generado
VIDEO_OUTPUT=$(find "$TMPDIR" -name "*.mp4" | head -1)

if [ -z "$VIDEO_OUTPUT" ]; then
    echo "❌ SadTalker no generó video"
    rm -rf "$TMPDIR"
    exit 1
fi

# Mover a output final
mv "$VIDEO_OUTPUT" "$OUTPUT_FILE"
rm -rf "$TMPDIR"

echo ""
echo "=================================================="
echo "   ✅ VIDEO GENERADO EXITOSAMENTE"
echo "=================================================="
echo "Output: $OUTPUT_FILE"
echo "Tamaño: $(du -h "$OUTPUT_FILE" | cut -f1)"
echo ""
