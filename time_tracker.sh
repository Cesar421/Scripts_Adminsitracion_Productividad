#!/bin/bash
# time_tracker.sh
# Registra el tiempo que pasas en cada proyecto
# Uso:
#   ./time_tracker.sh start <proyecto>   # Iniciar sesión
#   ./time_tracker.sh stop               # Detener sesión activa
#   ./time_tracker.sh status             # Ver sesión activa
#   ./time_tracker.sh report             # Reporte de horas por proyecto
#   ./time_tracker.sh report <proyecto>  # Reporte de un proyecto

STATE_FILE="$HOME/.time_tracker_state"
LOG_FILE="$HOME/.time_tracker.log"
CMD="${1:-status}"
PROJECT="${2:-}"

# Formato del log: FECHA|HORA_INICIO|HORA_FIN|PROYECTO|DURACION_SEG
log_entry() {
    echo "$1" >> "$LOG_FILE"
}

secs_to_hms() {
    local s=$1
    printf "%02d:%02d:%02d" $((s/3600)) $(( (s%3600)/60 )) $((s%60))
}

case "$CMD" in
    start)
        if [[ -z "$PROJECT" ]]; then
            echo "Error: especifica un nombre de proyecto"
            echo "Uso: $0 start <proyecto>"
            exit 1
        fi

        if [[ -f "$STATE_FILE" ]]; then
            active_proj=$(cat "$STATE_FILE" | cut -d'|' -f2)
            echo "⚠️  Ya hay una sesión activa: '$active_proj'"
            echo "Ejecuta '$0 stop' antes de iniciar otra"
            exit 1
        fi

        start_ts=$(date +%s)
        start_fmt=$(date '+%Y-%m-%d %H:%M:%S')
        echo "${start_ts}|${PROJECT}|${start_fmt}" > "$STATE_FILE"
        echo "▶ Iniciado: '$PROJECT'  ($start_fmt)"
        ;;

    stop)
        if [[ ! -f "$STATE_FILE" ]]; then
            echo "No hay sesión activa"
            exit 0
        fi

        start_ts=$(cat "$STATE_FILE" | cut -d'|' -f1)
        project=$(cat "$STATE_FILE"  | cut -d'|' -f2)
        start_fmt=$(cat "$STATE_FILE" | cut -d'|' -f3)

        end_ts=$(date +%s)
        end_fmt=$(date '+%Y-%m-%d %H:%M:%S')
        duration_s=$((end_ts - start_ts))
        duration_hms=$(secs_to_hms "$duration_s")
        date_only=$(date '+%Y-%m-%d')

        log_entry "${date_only}|${start_fmt}|${end_fmt}|${project}|${duration_s}"
        rm -f "$STATE_FILE"

        echo "⏹  Detenido: '$project'"
        echo "   Duración: $duration_hms  ($start_fmt → $end_fmt)"
        ;;

    status)
        if [[ ! -f "$STATE_FILE" ]]; then
            echo "No hay sesión activa"
        else
            start_ts=$(cat "$STATE_FILE" | cut -d'|' -f1)
            project=$(cat "$STATE_FILE"  | cut -d'|' -f2)
            start_fmt=$(cat "$STATE_FILE" | cut -d'|' -f3)
            elapsed=$(($(date +%s) - start_ts))
            echo "▶ Activo: '$project'"
            echo "  Inicio   : $start_fmt"
            echo "  Transcurrido: $(secs_to_hms $elapsed)"
        fi
        ;;

    report)
        if [[ ! -f "$LOG_FILE" ]]; then
            echo "No hay registros todavía"
            exit 0
        fi

        echo "======================================"
        echo " REPORTE DE TIEMPO"
        echo "======================================"
        echo ""

        if [[ -n "$PROJECT" ]]; then
            # Reporte de un proyecto específico
            echo "── Proyecto: $PROJECT ───────────────────"
            printf "  %-12s %-20s %-20s %s\n" "FECHA" "INICIO" "FIN" "DURACIÓN"
            printf "  %-12s %-20s %-20s %s\n" "------------" "--------------------" "--------------------" "--------"
            total_secs=0
            while IFS='|' read -r date start end proj secs; do
                [[ "$proj" != "$PROJECT" ]] && continue
                total_secs=$((total_secs + secs))
                printf "  %-12s %-20s %-20s %s\n" "$date" "$start" "$end" "$(secs_to_hms $secs)"
            done < "$LOG_FILE"
            echo ""
            echo "  Total: $(secs_to_hms $total_secs)"
        else
            # Reporte global por proyecto
            echo "── Tiempo por proyecto ──────────────────"
            printf "  %-30s %10s %8s\n" "PROYECTO" "TOTAL" "SESIONES"
            printf "  %-30s %10s %8s\n" "$(printf -- '-%.0s' {1..30})" "----------" "--------"

            declare -A proj_secs
            declare -A proj_count

            while IFS='|' read -r date start end proj secs; do
                proj_secs["$proj"]=$(( ${proj_secs["$proj"]:-0} + secs ))
                proj_count["$proj"]=$(( ${proj_count["$proj"]:-0} + 1 ))
            done < "$LOG_FILE"

            # Ordenar por tiempo descendente
            for proj in "${!proj_secs[@]}"; do
                echo "${proj_secs[$proj]} $proj ${proj_count[$proj]}"
            done | sort -rn | while read -r secs proj count; do
                printf "  %-30s %10s %8d\n" "$proj" "$(secs_to_hms $secs)" "$count"
            done

            echo ""
            echo "── Actividad reciente (últimas 10) ──────"
            printf "  %-12s %-25s %s\n" "FECHA" "PROYECTO" "DURACIÓN"
            printf "  %-12s %-25s %s\n" "------------" "-------------------------" "--------"
            tail -10 "$LOG_FILE" | while IFS='|' read -r date start end proj secs; do
                printf "  %-12s %-25s %s\n" "$date" "$proj" "$(secs_to_hms $secs)"
            done
        fi
        echo ""
        ;;

    *)
        echo "Uso: $0 {start <proyecto>|stop|status|report [proyecto]}"
        ;;
esac
