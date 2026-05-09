#!/bin/bash
# Test script for Qwen3.6 35B model in KlawAqua ecosystem

MODEL="qwen3.6:35b-a3b"

echo "=== Testing Qwen3.6 35B ==="
echo "Model: $MODEL"
echo "Date: $(date)"
echo ""

# Check if model is available
echo "1. Checking model availability..."
ollama list | grep -q "$MODEL"
if [ $? -eq 0 ]; then
    echo "   ✓ Model installed"
else
    echo "   ✗ Model not found, pulling..."
    ollama pull $MODEL
fi

# Basic inference test
echo ""
echo "2. Running basic inference test..."
ollama run $MODEL "Hola, soy el ecosistema KlawAqua. ¿Cómo estás?" --noword 2>/dev/null | head -3

# Check GPU usage
echo ""
echo "3. GPU Status:"
nvidia-smi --query-gpu=name,memory.total,memory.used,memory.free --format=csv,noheader 2>/dev/null || echo "   NVIDIA GPU not detected or nvidia-smi not available"

echo ""
echo "=== Test Complete ==="
