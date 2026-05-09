#!/bin/bash
# KLAWAQUA-AGI: ECOSYSTEM SHUTDOWN SCRIPT
# Apaga TODO el ecosistema de forma segura
# bash /opt/klawaqua/scripts/klawaqua-stop.sh

echo "═══════════════════════════════════════════════════════"
echo "   🛑 KLAWAQUA-AGI: APAGANDO ECOSISTEMA"
echo "   Guardando estado y deteniendo servicios..."
echo "═══════════════════════════════════════════════════════"
echo ""

# 1. Detener agentes en background
echo "[1/6] Deteniendo procesos en background..."
pkill -f "merlyn_bot" 2>/dev/null && echo "  ✅ Telegram Bot detenido"
pkill -f "openclaw.*gateway" 2>/dev/null && echo "  ✅ OpenCLAW Gateway detenido"
pkill -f "hermes_cli.main gateway" 2>/dev/null && echo "  ✅ Hermes Gateway detenido"
echo ""

# 2. Detener contenedores Docker
echo "[2/6] Deteniendo contenedores Docker..."
docker stop agent-zero > /dev/null 2>&1 && echo "  ✅ Agent Zero"
docker stop openhands-app- > /dev/null 2>&1 && echo "  ✅ OpenHands"
docker stop thepopebot-event-handler > /dev/null 2>&1 && echo "  ✅ ThePopeBot Event Handler"
docker stop thepopebot-instance-litellm-1 > /dev/null 2>&1 && echo "  ✅ LiteLLM"
docker stop redis > /dev/null 2>&1 && echo "  ✅ Redis"
docker stop postgres_letta > /dev/null 2>&1 && echo "  ✅ PostgreSQL"
echo ""

# 3. NOT detener Ollama (puede ser usado por otros)
echo "[3/6] Manteniendo Ollama activo (opcional)"
echo "  ℹ️ Para detener Ollama: sudo systemctl stop ollama"
echo ""

# 4. Guardar estado actual
echo "[4/6] Guardando estado del ecosistema..."
cat > /opt/klawaqua/state/last_shutdown.txt << EOF
KLAWAQUA-AGI SHUTDOWN REPORT
════════════════════════════
Fecha: $(date '+%Y-%m-%d %H:%M:%S')
Estado: COMPLETAMENTE APAGADO

Servicios detenidos:
- Agent Zero
- OpenHands
- ThePopeBot
- LiteLLM
- Redis
- Postgres
- OpenCLAW Gateway
- Telegram Bot

Para reiniciar:
  bash /opt/klawaqua/scripts/klawaqua-start.sh
  O desde Hermes:
  hermes -z "Inicia el ecosistema KlawAqua"
EOF
echo "  ✅ Estado guardado en /opt/klawaqua/state/last_shutdown.txt"
echo ""

# 5. Limpieza de caches temporales
echo "[5/6] Limpiando temporales..."
rm -f /tmp/telegram*.log /tmp/merlyn*.log /tmp/gateway.log 2>/dev/null
echo "  ✅ Temporales limpiados"
echo ""

# 6. Resumen final
echo "[6/6] Resumen final..."
echo ""
echo "═══════════════════════════════════════════════════════"
echo "   ✅ KLAWAQUA-AGI APAGADO COMPLETAMENTE"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "📊 ESTADO:"
echo "   ❌ Agent Zero (localhost:5080)"
echo "   ❌ OpenHands (localhost:3000)"
echo "   ❌ ThePopeBot (localhost:8080)"
echo "   ❌ OpenCLAW (localhost:18789)"
echo "   ❌ LiteLLM (localhost:4000)"
echo "   ❌ Redis (localhost:6380)"
echo "   ❌ PostgreSQL (localhost:5433)"
echo "   ❌ Telegram Bot"
echo "   ⚠️ Ollama (mantenido activo)"
echo ""
echo "💾 BACKUP:"
echo "   • Estado guardado"
echo "   • Logs limpiados"
echo "   • Temporales eliminados"
echo ""
echo "🚀 PARA REINICIAR:"
echo ""
echo "   Opción A: Desde línea de comandos"
echo "   bash /opt/klawaqua/scripts/klawaqua-start.sh"
echo ""
echo "   Opción B: Desde Hermes CLI (cuando enciendas)"
echo "   hermes -z \"Inicia todo el ecosistema KlawAqua\""
echo ""
echo "   Opción C: Crear skill de Hermes"
echo "   hermes skill run klawaqua-start"
echo ""
echo "═══════════════════════════════════════════════════════"
echo "   💤 ECOSISTEMA EN REPOSO - HASTA LA PRÓXIMA"
echo "═══════════════════════════════════════════════════════"
