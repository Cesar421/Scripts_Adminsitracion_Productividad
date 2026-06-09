#!/bin/bash
# realtime_monitor.sh
# Dashboard en tiempo real con gráficas de CPU, GPU, RAM

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Variables
REFRESH_INTERVAL="${1:-2}"
HISTORY_SIZE=60
declare -a CPU_HISTORY
declare -a RAM_HISTORY
declare -a GPU_HISTORY
HAS_GPU=false

# Detectar si hay GPU NVIDIA
check_gpu() {
    if command -v nvidia-smi &>/dev/null; then
        HAS_GPU=true
    fi
}

# Obtener CPU actual (promedio)
get_cpu() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {printf "%.0f", usage}'
    else
        # Windows/MINGW64 - usar PowerShell
        powershell -Command "Get-WmiObject Win32_Processor | Select-Object -ExpandProperty LoadPercentage" 2>/dev/null || echo "0"
    fi
}

# Obtener RAM actual
get_ram() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        free | grep Mem | awk '{printf "%.0f", $3/$2 * 100}'
    else
        # Windows - usar PowerShell
        powershell -Command "Get-WmiObject Win32_OperatingSystem | ForEach-Object {[math]::Round(($_.TotalVisibleMemorySize - $_.FreePhysicalMemory) / $_.TotalVisibleMemorySize * 100)}" 2>/dev/null || echo "0"
    fi
}

# Obtener GPU NVIDIA
get_gpu() {
    if [[ "$HAS_GPU" == true ]]; then
        nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | head -1
    else
        echo "N/A"
    fi
}

# Obtener temperatura CPU (si está disponible)
get_cpu_temp() {
    if command -v sensors &>/dev/null; then
        sensors 2>/dev/null | grep "Core" | awk '{print $3}' | sed 's/+//g' | sed 's/°C//g' | head -1
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        sysctl -n hw.thermal.level 2>/dev/null || echo "N/A"
    else
        echo "N/A"
    fi
}

# Obtener temperatura GPU NVIDIA
get_gpu_temp() {
    if [[ "$HAS_GPU" == true ]]; then
        nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits | head -1
    else
        echo "N/A"
    fi
}

# Crear barra gráfica ASCII
create_bar() {
    local value=$1
    local max=100
    local width=30
    local filled=$(( (value * width) / max ))
    local empty=$(( width - filled ))
    
    # Seleccionar color según valor
    if (( value >= 80 )); then
        color=$RED
    elif (( value >= 60 )); then
        color=$YELLOW
    else
        color=$GREEN
    fi
    
    printf "${color}"
    printf "█%.0s" $(seq 1 "$filled")
    printf "${NC}"
    printf "░%.0s" $(seq 1 "$empty")
    printf " %3d%%\n" "$value"
}

# Crear gráfica de histórico (pequeña)
create_sparkline() {
    local -a data=("$@")
    local sparkline="▁▂▃▄▅▆▇█"
    local result=""
    
    for val in "${data[@]}"; do
        if [[ -z "$val" ]] || [[ "$val" == "N/A" ]]; then
            result+=" "
        else
            local idx=$(( (val * 8) / 100 ))
            [[ $idx -gt 7 ]] && idx=7
            result+="${sparkline:$idx:1}"
        fi
    done
    echo "$result"
}

# Obtener top procesos por CPU
get_top_processes_cpu() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        ps aux --sort=-%cpu | head -4 | tail -3 | awk '{printf "  %-8s %5s%%  %s\n", $1, $3, $11}' | cut -c1-50
    else
        powershell -Command "Get-Process | Sort-Object CPU -Descending | Select-Object -First 3 | Format-Table -AutoSize @{Label='USER';Expression={$env:USERNAME}},@{Label='CPU%';Expression={'{0:N0}' -f [math]::Min($_.CPU, 100)}},@{Label='NAME';Expression={$_.ProcessName}} -HideTableHeaders" 2>/dev/null
    fi
}

# Obtener top procesos por RAM
get_top_processes_mem() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        ps aux --sort=-%mem | head -4 | tail -3 | awk '{printf "  %-8s %5s%%  %s\n", $1, $4, $11}' | cut -c1-50
    else
        powershell -Command "Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 3 | Format-Table -AutoSize @{Label='USER';Expression={$env:USERNAME}},@{Label='MEM%';Expression={'{0:N1}' -f (($_.WorkingSet / (Get-WmiObject Win32_OperatingSystem).TotalVisibleMemorySize) * 100)}},@{Label='NAME';Expression={$_.ProcessName}} -HideTableHeaders" 2>/dev/null
    fi
}

# Obtener info del sistema
get_system_info() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "$(uname -s) $(uname -r)"
    else
        powershell -Command "[System.Environment]::OSVersion.VersionString" 2>/dev/null | head -1
    fi
}

# Obtener carga del sistema
get_load_average() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        uptime | awk -F'load average:' '{print $2}' | xargs
    else
        echo "N/A"
    fi
}

# Limpiar pantalla y mostrar dashboard
show_dashboard() {
    clear
    
    local cpu=$(get_cpu)
    local ram=$(get_ram)
    local gpu=$(get_gpu)
    local cpu_temp=$(get_cpu_temp)
    local gpu_temp=$(get_gpu_temp)
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Agregar a histórico
    CPU_HISTORY+=("$cpu")
    RAM_HISTORY+=("$ram")
    [[ "$HAS_GPU" == true ]] && GPU_HISTORY+=("$gpu")
    
    # Mantener tamaño de histórico
    if (( ${#CPU_HISTORY[@]} > HISTORY_SIZE )); then
        CPU_HISTORY=("${CPU_HISTORY[@]:1}")
        RAM_HISTORY=("${RAM_HISTORY[@]:1}")
        [[ "$HAS_GPU" == true ]] && GPU_HISTORY=("${GPU_HISTORY[@]:1}")
    fi
    
    # Header
    echo ""
    printf "${CYAN}╔════════════════════════════════════════════════════════════════════╗${NC}\n"
    printf "${CYAN}║${NC}  📊 MONITOR DE SISTEMA EN TIEMPO REAL  [$timestamp]        ${CYAN}║${NC}\n"
    printf "${CYAN}╚════════════════════════════════════════════════════════════════════╝${NC}\n"
    echo ""
    
    # CPU
    printf "${MAGENTA}CPU:${NC}\n"
    printf "  Uso: "
    create_bar "$cpu"
    printf "  Temp: ${cpu_temp}°C\n"
    printf "  Histórico: "
    create_sparkline "${CPU_HISTORY[@]}"
    echo ""
    
    # RAM
    printf "${MAGENTA}RAM:${NC}\n"
    printf "  Uso: "
    create_bar "$ram"
    printf "  Histórico: "
    create_sparkline "${RAM_HISTORY[@]}"
    echo ""
    
    # GPU (si disponible)
    if [[ "$HAS_GPU" == true ]]; then
        printf "${MAGENTA}GPU (NVIDIA):${NC}\n"
        if [[ "$gpu" != "N/A" ]]; then
            printf "  Uso: "
            create_bar "$gpu"
            printf "  Temp: ${gpu_temp}°C\n"
            printf "  Histórico: "
            create_sparkline "${GPU_HISTORY[@]}"
        else
            printf "  No disponible\n"
        fi
        echo ""
    fi
    
    # Sistema
    printf "${MAGENTA}SISTEMA:${NC}\n"
    printf "  OS: $(get_system_info)\n"
    printf "  Carga: $(get_load_average)\n"
    echo ""
    
    # Top Procesos
    printf "${MAGENTA}TOP PROCESOS (CPU):${NC}\n"
    get_top_processes_cpu
    echo ""
    
    printf "${MAGENTA}TOP PROCESOS (RAM):${NC}\n"
    get_top_processes_mem
    echo ""
    
    printf "${CYAN}═══════════════════════════════════════════════════════════════════════${NC}\n"
    printf "Presiona ${YELLOW}Ctrl+C${NC} para salir | Refresco: ${YELLOW}${REFRESH_INTERVAL}s${NC}\n"
    echo ""
}

# Función principal
main() {
    check_gpu
    
    if [[ "$HAS_GPU" == true ]]; then
        echo "GPU NVIDIA detectada ✓"
    fi
    
    # Loop infinito
    while true; do
        show_dashboard
        sleep "$REFRESH_INTERVAL"
    done
}

# Manejar Ctrl+C
trap 'echo -e "\n${GREEN}Monitor detenido.${NC}"; exit 0' INT

# Ejecutar
main
