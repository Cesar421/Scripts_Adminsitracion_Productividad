#!/bin/bash
# system_report.sh
# Reporte general del sistema: CPU, RAM, disco, procesos

SEP="======================================"

echo "$SEP"
echo " REPORTE DEL SISTEMA — $(date '+%Y-%m-%d %H:%M:%S')"
echo "$SEP"
echo ""

# ── SO y Kernel ────────────────────────────────────────────────────────────
echo "── SISTEMA ──────────────────────────────"
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    printf "  %-20s %s\n" "OS:" "$PRETTY_NAME"
fi
printf "  %-20s %s\n" "Kernel:" "$(uname -r)"
printf "  %-20s %s\n" "Hostname:" "$(hostname)"
printf "  %-20s %s\n" "Uptime:" "$(uptime -p 2>/dev/null || uptime)"
echo ""

# ── CPU ───────────────────────────────────────────────────────────────────
echo "── CPU ──────────────────────────────────"
cpu_model=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs)
cpu_cores=$(nproc 2>/dev/null)
cpu_usage=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1)
load=$(cat /proc/loadavg 2>/dev/null | awk '{print $1, $2, $3}')

printf "  %-20s %s\n" "Modelo:" "${cpu_model:-N/A}"
printf "  %-20s %s\n" "Núcleos:" "${cpu_cores:-N/A}"
printf "  %-20s %s%%\n" "Uso actual:" "${cpu_usage:-N/A}"
printf "  %-20s %s (1m 5m 15m)\n" "Carga:" "${load:-N/A}"
echo ""

# ── RAM ───────────────────────────────────────────────────────────────────
echo "── MEMORIA RAM ──────────────────────────"
if command -v free &>/dev/null; then
    total_ram=$(free -h | awk '/^Mem:/{print $2}')
    used_ram=$(free -h  | awk '/^Mem:/{print $3}')
    free_ram=$(free -h  | awk '/^Mem:/{print $4}')
    pct_used=$(free     | awk '/^Mem:/{printf "%.1f", $3/$2*100}')
    printf "  %-20s %s\n" "Total:" "$total_ram"
    printf "  %-20s %s  (%.0f%%)\n" "Usada:" "$used_ram" "$pct_used"
    printf "  %-20s %s\n" "Libre:" "$free_ram"
else
    echo "  (free no disponible)"
fi
echo ""

# ── DISCO ─────────────────────────────────────────────────────────────────
echo "── DISCO ────────────────────────────────"
printf "  %-25s %8s %8s %8s %6s\n" "Partición" "Total" "Usado" "Libre" "Uso%"
printf "  %-25s %8s %8s %8s %6s\n" "$(printf -- '-%.0s' {1..25})" "--------" "--------" "--------" "------"
df -h --output=target,size,used,avail,pcent 2>/dev/null | tail -n +2 | \
    grep -v "^/snap\|^tmpfs\|^udev\|^/dev/loop" | \
    while read -r target size used avail pct; do
        printf "  %-25s %8s %8s %8s %6s\n" "$target" "$size" "$used" "$avail" "$pct"
    done
echo ""

# ── TOP 10 PROCESOS por CPU ────────────────────────────────────────────────
echo "── TOP 10 PROCESOS (CPU) ────────────────"
printf "  %6s %6s %-30s\n" "%CPU" "%MEM" "PROCESO"
printf "  %6s %6s %-30s\n" "------" "------" "$(printf -- '-%.0s' {1..30})"
ps aux --sort=-%cpu 2>/dev/null | tail -n +2 | head -10 | \
    awk '{printf "  %6s %6s %-30s\n", $3, $4, $11}'
echo ""

# ── TOP 10 PROCESOS por RAM ────────────────────────────────────────────────
echo "── TOP 10 PROCESOS (RAM) ────────────────"
printf "  %6s %6s %-30s\n" "%MEM" "%CPU" "PROCESO"
printf "  %6s %6s %-30s\n" "------" "------" "$(printf -- '-%.0s' {1..30})"
ps aux --sort=-%mem 2>/dev/null | tail -n +2 | head -10 | \
    awk '{printf "  %6s %6s %-30s\n", $4, $3, $11}'
echo ""

echo "$SEP"
echo " Reporte generado: $(date '+%Y-%m-%d %H:%M:%S')"
echo "$SEP"
