#!/bin/bash
# KLAWAQUA-AGI: Telegram Hermes Manager
# Inicia/Detiene el poller directo Hermes

PIDFILE="/tmp/telegram_hermes.pid"
SCRIPT="/opt/klawaqua/scripts/telegram-hermes-direct.sh"
LOGFILE="/tmp/telegram_hermes.log"

case "${1:-start}" in
    start)
        if [ -f "$PIDFILE" ] && ps -p "$(cat $PIDFILE)" > /dev/null 2>&1; then
            echo "✅ Telegram Hermes YA está corriendo (PID: $(cat $PIDFILE))"
            echo "Para reiniciar: $0 restart"
            exit 0
        fi
        
        echo "Iniciando Telegram → Hermes Directo..."
        
        # Cargar variables
        [ -f "$HOME/.hermes/.env" ] && source "$HOME/.hermes/.env"
        
        if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
            echo "❌ TELEGRAM_BOT_TOKEN no configurado en ~/.hermes/.env"
            exit 1
        fi
        
        # Iniciar en background
        nohup bash "$SCRIPT" > "$LOGFILE" 2>&1 &
        echo $! > "$PIDFILE"
        
        sleep 3
        
        if ps -p "$(cat $PIDFILE)" > /dev/null 2>&1; then
            echo "✅ Telegram → Hermes ACTIVO (PID: $(cat $PIDFILE))"
            echo "Logs: tail -f $LOGFILE"
            echo "Detener: $0 stop"
        else
            echo "❌ Error al iniciar. Ver: $LOGFILE"
            rm -f "$PIDFILE"
            exit 1
        fi
        ;;
    
    stop)
        if [ -f "$PIDFILE" ]; then
            kill "$(cat $PIDFILE)" 2>/dev/null || true
            rm -f "$PIDFILE"
            echo "✅ Telegram Hermes detenido"
        else
            echo "ℹ️  No hay proceso corriendo"
        fi
        pkill -f "telegram-hermes-direct.sh" 2>/dev/null || true
        ;;
    
    restart)
        $0 stop
        sleep 2
        $0 start
        ;;
    
    status)
        if [ -f "$PIDFILE" ] && ps -p "$(cat $PIDFILE)" > /dev/null 2>&1; then
            echo "✅ Activo (PID: $(cat $PIDFILE))"
            tail -5 "$LOGFILE"
        else
            echo "❌ Inactivo"
        fi
        ;;
    
    logs)
        tail -f "$LOGFILE"
        ;;
    
    *)
        echo "Uso: $0 {start|stop|restart|status|logs}"
        exit 1
        ;;
esac
