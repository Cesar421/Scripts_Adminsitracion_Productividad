#!/bin/bash
# realtime_monitor.sh (OPTIMIZADO)
# Dashboard en tiempo real con gráficas de CPU, GPU, RAM - RÁPIDO

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Variables
REFRESH_INTERVAL="${1:-1}"
HISTORY_SIZE=30
declare -a CPU_HISTORY
declare -a RAM_HISTORY
HAS_GPU=false
IS_WINDOWS=false

# Detectar SO
detect_os() {
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
        IS_WINDOWS=true
    fi
    if command -v nvidia-smi &>/dev/null; then
        HAS_GPU=true
    fi
}

# Obtener CPU (RÁPIDO)
get_cpu() {
    if [[ "$IS_WINDOWS" == true ]]; then
        powershell.exe -NoProfile -Command "(Get-WmiObject Win32_Processor).LoadPercentage" 2>/dev/null || echo "0"
    else
        grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {printf "%.0f", usage}'
    fi
}

# Obtener RAM (RÁPIDO)
get_ram() {
    if [[ "$IS_WINDOWS" == true ]]; then
        powershell.exe -NoProfile -Command "[math]::Round((Get-WmiObject Win32_OperatingSystem | ForEach-Object {(1-($_.FreePhysicalMemory/$_.TotalVisibleMemorySize))*100}))" 2>/dev/null || echo "0"
    else
        free | grep Mem | awk '{printf "%.0f", $3/$2 * 100}'
    fi
}

# Obtener GPU
get_gpu() {
    if [[ "$HAS_GPU" == true ]]; then
        nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | head -1
    else
        echo "N/A"
    fi
}

# Obtener temperatura
get_cpu_temp() {
    if command -v sensors &>/dev/null; then
        sensors 2>/dev/null | grep "Core" | awk '{print $3}' | sed 's/[^0-9.]//g' | head -1 || echo "N/A"
    else
        echo "N/A"
    fi
}

# Top procesos por CPU
get_top_processes_cpu() {
    if [[ "$IS_WINDOWS" == true ]]; then
        powershell.exe -NoProfile -Command "Get-Process | Sort-Object CPU -Descending | Select-Object -First 3 | ForEach-Object {'{0,-12} {1:N0}%   {2}' -f ($env:USERNAME), [math]::Min([int]$_.CPU, 100), $_.ProcessName}" 2>/dev/null | head -3
    else
        ps aux --sort=-%cpu | tail -3 | awk '{printf "  %-12s %3s%%   %s\n", $1, int($3), $11}' | head -3
    fi
}

# Top procesos por RAM
get_top_processes_mem() {
    if [[ "$IS_WINDOWS" == true ]]; then
        powershell.exe -NoProfile -Command "Get-WmiObject Win32_Process | Sort-Object WorkingSetSize -Descending | Select-Object -First 3 | ForEach-Object {[int]\$mem_pct = ((\$_.WorkingSetSize / (Get-WmiObject Win32_OperatingSystem).TotalVisibleMemorySize) * 100); '{0,-12} {1:N1}%   {2}' -f ($env:USERNAME), \$mem_pct, \$_.Name}" 2>/dev/null | head -3
    else
        ps aux --sort=-%mem | tail -3 | awk '{printf "  %-12s %3s%%   %s\n", $1, int($4), $11}' | head -3
    fi
}

# Crear barra gráfica ASCII
create_bar() {
    local value=$1
    local max=100
    local width=25
    local filled=$(( (value * width) / max ))
    local empty=$(( width - filled ))
    
    if (( value >= 80 )); then
        printf "${RED}"
    elif (( value >= 60 )); then
        printf "${YELLOW}"
    else
        printf "${GREEN}"
    fi
    
    printf "█%.0s" $(seq 1 "$filled")
    printf "${NC}"
    printf "░%.0s" $(seq 1 "$empty")
    printf " %3d%%\n" "$value"
}

# Mostrar dashboard sin limpiar pantalla (ACTUALIZACIÓN EN VIVO)
show_dashboard_first_time() {
    # Header inicial que no se borra
    printf "\n${CYAN}╔═════════════════════════════════════════════════════════════╗${NC}\n"
    printf "${CYAN}║${NC}            📊 MONITOR DE SISTEMA EN TIEMPO REAL            ${CYAN}║${NC}\n"
    printf "${CYAN}╚═════════════════════════════════════════════════════════════╝${NC}\n\n"
}

show_dashboard() {
    local cpu=$(get_cpu)
    local ram=$(get_ram)
    local gpu=$(get_gpu)
    local timestamp=$(date '+%H:%M:%S')
    
    # Agregar a histórico
    CPU_HISTORY+=("$cpu")
    RAM_HISTORY+=("$ram")
    
    # Mantener tamaño de histórico
    if (( ${#CPU_HISTORY[@]} > HISTORY_SIZE )); then
        CPU_HISTORY=("${CPU_HISTORY[@]:1}")
        RAM_HISTORY=("${RAM_HISTORY[@]:1}")
    fi
    
    # Si es la primera vez, mostrar el header
    if [[ -z "$FIRST_RUN" ]]; then
        show_dashboard_first_time
        FIRST_RUN=1
        LINES_TO_CLEAR=11
    else
        # Mover cursor hacia arriba para sobrescribir
        printf "\033[${LINES_TO_CLEAR}A\033[J"
    fi
    
    # Timestamp
    printf "  ${CYAN}[%s]${NC}\n\n" "$timestamp"
    
    # CPU
    printf "${MAGENTA}CPU:${NC}   "
    create_bar "$cpu"
    
    # RAM
    printf "${MAGENTA}RAM:${NC}   "
    create_bar "$ram"
    
    # GPU
    if [[ "$HAS_GPU" == true ]] && [[ "$gpu" != "N/A" ]]; then
        printf "${MAGENTA}GPU:${NC}   "
        create_bar "$gpu"
    fi
    
    printf "\n${MAGENTA}┌─ TOP PROCESOS ─────────────────────────────────────┐${NC}\n"
    printf "${YELLOW}CPU:${NC}\n"
    get_top_processes_cpu
    printf "\n${YELLOW}RAM:${NC}\n"
    get_top_processes_mem
    printf "\n${MAGENTA}└────────────────────────────────────────────────────┘${NC}\n"
    printf "  ${CYAN}Ctrl+C${NC} para salir | Intervalo: ${YELLOW}${REFRESH_INTERVAL}s${NC}\n"
}

# Variables globales para control
FIRST_RUN=""
LINES_TO_CLEAR=11

# Función principal
main() {
    detect_os
    
    # Loop infinito - actualiza sin limpiar pantalla
    while true; do
        show_dashboard
        sleep "$REFRESH_INTERVAL"
    done
}

# Manejar Ctrl+C
trap 'echo -e "\n\n${GREEN}✓ Monitor detenido${NC}\n"; exit 0' INT

# Ejecutar
main
