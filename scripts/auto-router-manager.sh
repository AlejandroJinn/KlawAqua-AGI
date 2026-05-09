#!/bin/bash
# KLAWAQUA-AGI: Auto Router Manager
# Mantiene el router local↔cloud siempre activo

PIDFILE="/tmp/auto_router.pid"
LOGFILE="/opt/klawaqua/logs/auto_router.log"
WARMUP_SCRIPT="/opt/klawaqua/scripts/router_warmup.py"

case "${1:-start}" in
    start)
        if [ -f "$PIDFILE" ] && ps -p "$(cat $PIDFILE)" > /dev/null 2>&1; then
            echo "✅ Router YA está corriendo (PID: $(cat $PIDFILE))"
            exit 0
        fi
        
        echo "Iniciando Auto Router..."
        
        # Warmup: verificar todos los modelos al inicio
        if [ -f "$WARMUP_SCRIPT" ]; then
            echo "🔥 Warmup de modelos..."
            python3 "$WARMUP_SCRIPT" &
        fi
        
        # El router corre on-demand en cada llamada
        # No es un proceso continuo
        echo "✅ Router listo (on-demand)"
        echo "   Se activa automáticamente con cada consulta"
        echo "   Log: $LOGFILE"
        ;;
    
    status)
        echo "Estado del Sistema Router:"
        echo "=========================="
        echo ""
        echo "📊 Modelos locales:"
        ollama list 2>/dev/null | grep -E "qwen|mistral" || echo "  (verificando...)"
        
        echo ""
        echo "☁️ Modelos cloud (OpenRouter free):"
        echo "  • nvidia/nemotron-3-super-120b-a12b:free"
        echo "  • poolside/laguna-m.1:free"
        echo "  • inclusionai/ling-2.6-1t:free"
        echo "  • stepfun/step-3.5-flash:free"
        echo "  • x-ai/grok-code-fast-1:optimized:free"
        
        echo ""
        echo "💾 Memoria persistente:"
        if [ -f "/opt/klawaqua/data/router_memory.db" ]; then
            size=$(du -h /opt/klawaqua/data/router_memory.db | cut -f1)
            echo "  ✅ Activa ($size)"
        else
            echo "  ⏳ Se creará con el primer uso"
        fi
        
        echo ""
        echo "🔧 Configuración:"
        if [ -f "/opt/klawaqua/config/router_config.json" ]; then
            echo "  ✅ /opt/klawaqua/config/router_config.json"
            cat /opt/klawaqua/config/router_config.json | python3 -m json.tool | head -10
        fi
        ;;
    
    test)
        echo "🧪 Test del Router..."
        echo ""
        
        echo "1. Probando modelo local..."
        timeout 10 ollama run qwen3.5:4b "Di OK" 2>/dev/null | head -1 || echo "  Local: No disponible"
        
        echo ""
        echo "2. Probando modelo cloud..."
        if [ -n "$OPENROUTER_API_KEY" ]; then
            timeout 10 curl -s -X POST "https://openrouter.ai/api/v1/chat/completions" \
                -H "Authorization: Bearer $OPENROUTER_API_KEY" \
                -H "Content-Type: application/json" \
                -d '{"model":"nvidia/nemotron-3-super-120b-a12b:free","messages":[{"role":"user","content":"Di OK"}],"max_tokens":5}' \
                2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('choices',[{}])[0]['message']['content'][:20] or 'Cloud: Error')" 2>/dev/null || echo "  Cloud: No disponible"
        else
            echo "  Cloud: OPENROUTER_API_KEY no configurada"
        fi
        
        echo ""
        echo "3. Test completo con auto_router.py..."
        cd /opt/klawaqua && python3 scripts/auto_router.py "Di hola" test_conv
        
        echo ""
        echo "✅ Test completado"
        ;;
    
    logs)
        tail -f "$LOGFILE" 2>/dev/null || echo "Log no existe aún"
        ;;
    
    clear-memory)
        echo "Limpiando memoria del router..."
        rm -f /opt/klawaqua/data/router_memory.db
        echo "✅ Memoria limpiada"
        ;;
    
    *)
        echo "Uso: $0 {start|status|test|logs|clear-memory}"
        echo ""
        echo "Comandos:"
        echo "  start       - Iniciar router (on-demand)"
        echo "  status      - Ver estado de modelos y memoria"
        echo "  test        - Test completo del sistema"
        echo "  logs        - Ver logs en tiempo real"
        echo "  clear-memory- Limpiar memoria persistente"
        exit 1
        ;;
esac
