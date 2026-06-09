#!/bin/bash
# network_speed_log.sh
# Mide la velocidad de descarga periódicamente usando curl y guarda historial
# Uso: ./network_speed_log.sh [intervalo_minutos] [archivo_log]

INTERVAL_MIN="${1:-5}"
LOG_FILE="${2:-$HOME/.network_speed.log}"
TEST_URL="http://speedtest.tele2.net/10MB.zip"   # Archivo de prueba público
INTERVAL_SEC=$((INTERVAL_MIN * 60))

echo "======================================"
echo " MONITOR DE VELOCIDAD DE RED"
echo " Intervalo : ${INTERVAL_MIN} min"
echo " Log       : $LOG_FILE"
echo " URL test  : $TEST_URL"
echo " Ctrl+C para detener"
echo "======================================"
echo ""

# Cabecera del log si es nuevo
if [[ ! -f "$LOG_FILE" ]]; then
    echo "FECHA,HORA,VELOCIDAD_Mbps,LATENCIA_ms,ESTADO" > "$LOG_FILE"
fi

measure() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d,%H:%M:%S')

    # Medir latencia (ping a DNS de Google)
    latency=$(ping -c 3 -W 2 8.8.8.8 2>/dev/null | tail -1 | awk -F'/' '{print $5}')
    latency="${latency:-N/A}"

    # Medir velocidad de descarga con curl
    result=$(curl -o /dev/null -s -w "%{speed_download} %{http_code}" \
        --max-time 30 "$TEST_URL" 2>/dev/null)

    speed_bytes=$(echo "$result" | awk '{print $1}')
    http_code=$(echo "$result" | awk '{print $2}')

    if [[ "$http_code" == "200" && -n "$speed_bytes" ]]; then
        speed_mbps=$(echo "scale=2; $speed_bytes * 8 / 1000000" | bc 2>/dev/null)
        estado="OK"
        echo "  [$(date '+%H:%M:%S')] ↓ ${speed_mbps} Mbps  |  ping: ${latency} ms"
        echo "${timestamp},${speed_mbps},${latency},${estado}" >> "$LOG_FILE"
    else
        echo "  [$(date '+%H:%M:%S')] ✗ Sin conexión (HTTP: ${http_code:-timeout})"
        echo "${timestamp},0,N/A,FALLO" >> "$LOG_FILE"
    fi
}

# Mostrar historial reciente si existe
if [[ -f "$LOG_FILE" ]]; then
    count=$(wc -l < "$LOG_FILE")
    if [[ $count -gt 1 ]]; then
        echo "── Últimas 5 mediciones ─────────────────"
        tail -5 "$LOG_FILE" | column -t -s','
        echo ""

        avg=$(tail -n +2 "$LOG_FILE" | awk -F',' '$4=="OK"{s+=$3; c++} END{if(c>0) printf "%.2f", s/c}')
        echo "  Promedio histórico: ${avg:-N/A} Mbps"
        echo ""
    fi
fi

echo "── Iniciando mediciones ─────────────────"
while true; do
    measure
    sleep "$INTERVAL_SEC"
done
