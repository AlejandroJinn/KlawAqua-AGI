#!/bin/bash
# KLAWAQUA-AGI: Avatar Pipeline Wrapper
# Usa Python del sistema con dependencias específicas

KLAWAQUA_BASE="/opt/klawaqua"
SCRIPT="$KLAWAQUA_BASE/scripts/avatar_pipeline.py"

# Check if required packages are installed
check_deps() {
    python3 -c "import edge_tts" 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "Instalando edge-tts..."
        pip install edge-tts --break-system-packages -q 2>/dev/null
    fi
}

# Run the pipeline
run_pipeline() {
    check_deps
    python3 "$SCRIPT" "$@"
}

# Main
if [ $# -eq 0 ]; then
    echo "KLAWAQUA-AGI Avatar Parlante Pipeline"
    echo ""
    echo "Uso:"
    echo "  $0 \"Texto a sintetizar\" output.mp4"
    echo "  $0 --llm \"Prompt\" --output video.mp4"
    echo "  $0 --input guion.txt --output video.mp4"
    echo ""
    echo "Ejemplo rápido:"
    echo "  $0 \"Hola, soy KlawAqua\" test.mp4"
    exit 1
fi

run_pipeline "$@"
