#!/bin/bash
# KLAWAQUA-AGI: Mantener qwen3.5:4b en VRAM
# Ejecutar esto para pre-cargar el modelo

echo "Manteniendo qwen3.5:4b activo en VRAM..."
echo "Presiona Ctrl+C para detener"
echo ""

while true; do
    # Enviar prompt vacío cada 30 segundos para mantener activo
    ollama run qwen3.5:4b "." > /dev/null 2>&1 &
    PID=$!
    sleep 30
    kill $PID 2>/dev/null
    echo "[$(date '+%H:%M:%S')] Modelo mantenido en VRAM"
done
