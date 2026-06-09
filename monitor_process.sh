#!/bin/bash
# monitor_process.sh
# Monitorea un proceso y lo reinicia si se cae
# Uso: ./monitor_process.sh <nombre_proceso> [comando_para_reiniciar] [intervalo_segundos]

PROCESS_NAME="${1:-}"
RESTART_CMD="${2:-}"
INTERVAL="${3:-10}"
LOG_FILE="${HOME}/.monitor_process.log"

if [[ -z "$PROCESS_NAME" ]]; then
    echo "Uso: $0 <nombre_proceso> [comando_reinicio] [intervalo_seg]"
    echo ""
    echo "Ejemplos:"
    echo "  $0 nginx                        # solo monitorea"
    echo "  $0 nginx 'sudo systemctl start nginx'  # monitorea y reinicia"
    echo "  $0 python 'python app.py &' 5   # revisa cada 5 segundos"
    exit 1
fi

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg"
    echo "$msg" >> "$LOG_FILE"
}

is_running() {
    pgrep -x "$PROCESS_NAME" &>/dev/null
}

echo "======================================"
echo " MONITOR DE PROCESO: $PROCESS_NAME"
echo " Intervalo: ${INTERVAL}s"
echo " Log: $LOG_FILE"
echo " Ctrl+C para detener"
echo "======================================"
echo ""

log "Iniciando monitoreo de '$PROCESS_NAME'"

restart_count=0
check_count=0

while true; do
    check_count=$((check_count + 1))

    if is_running; then
        pid=$(pgrep -x "$PROCESS_NAME" | head -1)
        cpu=$(ps -p "$pid" -o %cpu= 2>/dev/null | xargs)
        mem=$(ps -p "$pid" -o %mem= 2>/dev/null | xargs)
        printf "\r  [%s] ✓ '%s' corriendo (PID: %s | CPU: %s%% | MEM: %s%%)   " \
            "$(date '+%H:%M:%S')" "$PROCESS_NAME" "$pid" "$cpu" "$mem"
    else
        echo ""
        log "⚠️  '$PROCESS_NAME' NO está corriendo"

        if [[ -n "$RESTART_CMD" ]]; then
            log "Intentando reiniciar: $RESTART_CMD"
            eval "$RESTART_CMD"
            sleep 2
            if is_running; then
                restart_count=$((restart_count + 1))
                log "✓ '$PROCESS_NAME' reiniciado exitosamente (reinicio #$restart_count)"
            else
                log "✗ Fallo al reiniciar '$PROCESS_NAME'"
            fi
        else
            log "Sin comando de reinicio configurado — solo monitoreando"
        fi
    fi

    sleep "$INTERVAL"
done
