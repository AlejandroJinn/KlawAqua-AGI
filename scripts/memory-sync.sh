#!/bin/bash
# ============================================================
# KlawAqua - Memory Persistence & Continuity Bridge
# Syncs memories between ThePopeBot (SQLite) and Persistent Memory
# Runs on every message to keep continuity
# ============================================================

MEMORY_DB="/opt/klawaqua/data/klawaqua_persistent_memory.db"
THEPOPEBOT_DB="/opt/klawaqua/projects/thepopebot-instance/data/db/thepopebot.sqlite"

# Ensure persistent memory exists
python3 /opt/klawaqua/scripts/persistent_memory.py init

# Save system state
python3 /opt/klawaqua/scripts/persistent_memory.py save ecosystem_started "$(date -Iseconds)"
python3 /opt/klawaqua/scripts/persistent_memory.py save ollama_status "$(curl -s -m 2 localhost:11434/ > /dev/null && echo 'active' || echo 'inactive')"

echo "✅ Memoria persistente actualizada"
echo "   Models: $(ollama list 2>/dev/null | tail -n +2 | wc -l) disponibles"
python3 /opt/klawaqua/scripts/persistent_memory.py stats 2>&1
