#!/bin/bash

# System monitoring script
# Displays timestamp, CPU usage, memory, disk, GPU temp (if available), Ollama models
# Refreshes every 5 seconds, stop with Ctrl+C

INTERVAL=5

header() {
    echo "=== System Monitor ==="
}

while true; do
    clear
    header
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "Timestamp: $TIMESTAMP"

    # CPU usage: user, system, idle
    CPU_LINE=$(top -bn1 | grep "Cpu(s)")
    if [ -n "$CPU_LINE" ]; then
        USER_PCT=$(echo "$CPU_LINE" | awk -F'[, ]+' '{print $2}')
        SYS_PCT=$(echo "$CPU_LINE" | awk -F'[, ]+' '{print $4}')
        IDLE_PCT=$(echo "$CPU_LINE" | awk -F'[, ]+' '{print $8}')
        echo "CPU: user ${USER_PCT}%, system ${SYS_PCT}%, idle ${IDLE_PCT}%"
    else
        echo "CPU: unable to read"
    fi

    # Memory
    MEM_LINE=$(free -b | awk 'NR==2{printf "%d %d %.2f", $3, $2, $4*100/$2}')
    if [ -n "$MEM_LINE" ]; then
        USED_BYTES=$(echo "$MEM_LINE" | awk '{print $1}')
        TOTAL_BYTES=$(echo "$MEM_LINE" | awk '{print $2}')
        FREE_PCT=$(echo "$MEM_LINE" | awk '{print $3}')
        # Convert to human readable (MiB)
        USED_MB=$(($USED_BYTES/1024/1024))
        TOTAL_MB=$(($TOTAL_BYTES/1024/1024))
        echo "Memory: used ${USED_MB}MiB / total ${TOTAL_MB}MiB (free ${FREE_PCT}%)"
    else
        echo "Memory: unable to read"
    fi

    # Root disk usage
    DF_LINE=$(df -B1 / | awk 'NR==2{printf "%d %d %.2f", $3, $2, $5*100/$2}')
    if [ -n "$DF_LINE" ]; then
        USED_BYTES_D=$(echo "$DF_LINE" | awk '{print $1}')
        TOTAL_BYTES_D=$(echo "$DF_LINE" | awk '{print $2}')
        USED_PCT_D=$(echo "$DF_LINE" | awk '{print $3}')
        USED_GB=$(($USED_BYTES_D/1024/1024/1024))
        TOTAL_GB=$(($TOTAL_BYTES_D/1024/1024/1024))
        echo "Disk (/): used ${USED_GB}GiB / total ${TOTAL_GB}GiB (used ${USED_PCT_D}%)"
    else
        echo "Disk: unable to read"
    fi

    # GPU temperature if nvidia-smi available
    if command -v nvidia-smi >/dev/null 2>&1; then
        GPU_TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null)
        if [ -n "$GPU_TEMP" ]; then
            echo "GPU Temp: ${GPU_TEMP}°C"
        else
            echo "GPU Temp: unable to read"
        fi
    else
        echo "GPU Temp: nvidia-smi not available"
    fi

    # Ollama models
    if command -v ollama >/dev/null 2>&1; then
        OLLAMA_MODELS=$(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}')
        if [ -n "$OLLAMA_MODELS" ]; then
            echo "Ollama Models:"
            echo "$OLLAMA_MODELS" | while read model; do
                echo "  - $model"
            done
        else
            echo "Ollama Models: none found"
        fi
    else
        echo "Ollama: not installed"
    fi

    echo "--- Refreshing in $INTERVAL seconds (Ctrl+C to stop) ---"
    sleep $INTERVAL
done