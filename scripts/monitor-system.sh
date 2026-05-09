#!/bin/bash

# Simple system monitor script
# Displays CPU, memory, disk usage and GPU temperature every 5 seconds
# Press Ctrl+C to stop

# Trap Ctrl+C to exit cleanly
trap "echo -e '\nMonitoring stopped.'; exit 0" SIGINT

while true; do
    # Get timestamp
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
    
    # CPU usage (percentage)
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')  # user + system
    
    # Memory usage
    MEM_INFO=$(free -h | awk 'NR==2{printf "%.2f/%.2f GB (%s%%)\n", $3/1024, $2/1024, $3*100/$2}')
    
    # Disk usage (root partition)
    DISK_USAGE=$(df -h / | awk 'NR==2{printf "%s/%s (%s)\n", $3, $2, $5}')
    
    # GPU temperature (if nvidia-smi available)
    if command -v nvidia-smi &> /dev/null; then
        GPU_TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits)
        GPU_OUTPUT="GPU Temp: ${GPU_TEMP}°C"
    else
        GPU_OUTPUT="GPU Temp: N/A (nvidia-smi not found)"
    fi
    
    # Clear screen and print output
    clear
    echo "=== System Monitor ==="
    echo "Time: $TIMESTAMP"
    echo "CPU Usage: ${CPU_USAGE}%"
    echo "Memory Usage: $MEM_INFO"
    echo "Disk Usage (/): $DISK_USAGE"
    echo "$GPU_OUTPUT"
    echo "======================"
    echo "Press Ctrl+C to exit"
    
    # Wait 5 seconds
    sleep 5
done