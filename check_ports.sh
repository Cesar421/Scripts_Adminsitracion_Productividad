#!/bin/bash
# check_ports.sh
# Lista puertos en uso, procesos asociados y conexiones activas

echo "======================================"
echo " PUERTOS EN USO — $(date '+%Y-%m-%d %H:%M:%S')"
echo "======================================"
echo ""

# Detectar herramienta disponible
if command -v ss &>/dev/null; then
    TOOL="ss"
elif command -v netstat &>/dev/null; then
    TOOL="netstat"
else
    echo "Error: necesitas 'ss' o 'netstat' instalado"
    exit 1
fi

# ── Puertos en ESCUCHA (servidores activos) ────────────────────────────────
echo "── PUERTOS EN ESCUCHA ───────────────────"
printf "  %-8s %-25s %-10s %s\n" "PROTO" "DIRECCIÓN:PUERTO" "PID" "PROCESO"
printf "  %-8s %-25s %-10s %s\n" "--------" "$(printf -- '-%.0s' {1..25})" "----------" "-------"

if [[ "$TOOL" == "ss" ]]; then
    ss -tlnp 2>/dev/null | tail -n +2 | while read -r state recv send local remote proc; do
        pid=$(echo "$proc" | grep -oP 'pid=\K[0-9]+')
        name=$([ -n "$pid" ] && ps -p "$pid" -o comm= 2>/dev/null || echo "-")
        proto="TCP"
        printf "  %-8s %-25s %-10s %s\n" "$proto" "$local" "${pid:--}" "${name:--}"
    done
    ss -ulnp 2>/dev/null | tail -n +2 | while read -r state recv send local remote proc; do
        pid=$(echo "$proc" | grep -oP 'pid=\K[0-9]+')
        name=$([ -n "$pid" ] && ps -p "$pid" -o comm= 2>/dev/null || echo "-")
        proto="UDP"
        printf "  %-8s %-25s %-10s %s\n" "$proto" "$local" "${pid:--}" "${name:--}"
    done
else
    netstat -tlnp 2>/dev/null | tail -n +3 | while read -r proto recv send local remote state proc; do
        pid=$(echo "$proc" | cut -d/ -f1)
        name=$(echo "$proc" | cut -d/ -f2)
        printf "  %-8s %-25s %-10s %s\n" "$proto" "$local" "${pid:--}" "${name:--}"
    done
fi

echo ""

# ── Puertos específicos de interés ────────────────────────────────────────
echo "── PUERTOS COMUNES ──────────────────────"
declare -A PORT_NAMES=(
    [22]="SSH"    [80]="HTTP"    [443]="HTTPS"   [3000]="Node/React"
    [3306]="MySQL" [5432]="PostgreSQL" [6379]="Redis" [8080]="HTTP-alt"
    [8888]="Jupyter" [27017]="MongoDB" [5000]="Flask" [4200]="Angular"
)

printf "  %-8s %-15s %s\n" "PUERTO" "SERVICIO" "ESTADO"
printf "  %-8s %-15s %s\n" "--------" "---------------" "-------"

for port in $(echo "${!PORT_NAMES[@]}" | tr ' ' '\n' | sort -n); do
    service="${PORT_NAMES[$port]}"
    if ss -tln 2>/dev/null | grep -q ":${port} \|:${port}$" || \
       netstat -tln 2>/dev/null | grep -q ":${port} \|:${port}$"; then
        status="🟢 ACTIVO"
    else
        status="⚪ libre"
    fi
    printf "  %-8s %-15s %s\n" "$port" "$service" "$status"
done

echo ""

# ── Conexiones activas (ESTABLISHED) ─────────────────────────────────────
echo "── CONEXIONES ESTABLECIDAS (top 10) ─────"
printf "  %-25s %-25s %s\n" "LOCAL" "REMOTO" "PROCESO"
printf "  %-25s %-25s %s\n" "$(printf -- '-%.0s' {1..25})" "$(printf -- '-%.0s' {1..25})" "-------"

if [[ "$TOOL" == "ss" ]]; then
    ss -tnp state established 2>/dev/null | tail -n +2 | head -10 | \
    while read -r recv send local remote proc; do
        name=$(echo "$proc" | grep -oP '".*?"' | tr -d '"')
        printf "  %-25s %-25s %s\n" "$local" "$remote" "${name:--}"
    done
else
    netstat -tnp 2>/dev/null | grep ESTABLISHED | head -10 | \
    awk '{printf "  %-25s %-25s %s\n", $4, $5, $7}'
fi

echo ""
echo "Uso: $0           # listar todos los puertos en uso"
