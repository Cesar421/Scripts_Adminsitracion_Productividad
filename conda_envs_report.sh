#!/bin/bash
# conda_envs_report.sh
# Reporte de entornos Conda: tamaño, paquetes principales, versión de Python

echo "======================================"
echo " REPORTE DE ENTORNOS CONDA"
echo " $(date '+%Y-%m-%d %H:%M:%S')"
echo "======================================"
echo ""

# Verificar conda disponible
if ! command -v conda &>/dev/null; then
    echo "Error: conda no está disponible en el PATH"
    echo "Intenta: source ~/anaconda3/etc/profile.d/conda.sh"
    exit 1
fi

# Obtener lista de entornos
envs=$(conda env list 2>/dev/null | grep -v "^#" | grep -v "^$")
env_count=$(echo "$envs" | wc -l)

echo "  Entornos encontrados: $env_count"
echo ""

# ── Tabla resumen ──────────────────────────────────────────────────────────
echo "── RESUMEN ──────────────────────────────"
printf "  %-25s %-10s %-12s %s\n" "ENTORNO" "PYTHON" "TAMAÑO" "RUTA"
printf "  %-25s %-10s %-12s %s\n" "$(printf -- '-%.0s' {1..25})" "----------" "------------" "$(printf -- '-%.0s' {1..30})"

while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    env_name=$(echo "$line" | awk '{print $1}')
    env_path=$(echo "$line" | awk '{print $NF}')

    # Si la ruta es *, es el entorno activo — ajustar
    if [[ "$env_path" == "*" ]]; then
        env_path=$(echo "$line" | awk '{print $2}')
    fi

    # Versión de Python
    py_ver="N/A"
    if [[ -f "$env_path/bin/python" ]]; then
        py_ver=$("$env_path/bin/python" --version 2>&1 | awk '{print $2}')
    elif [[ -f "$env_path/python.exe" ]]; then
        py_ver=$("$env_path/python.exe" --version 2>&1 | awk '{print $2}')
    fi

    # Tamaño del entorno
    size=$(du -sh "$env_path" 2>/dev/null | cut -f1)

    # Marcar entorno activo
    active=""
    [[ "$CONDA_DEFAULT_ENV" == "$env_name" || "$CONDA_PREFIX" == "$env_path" ]] && active=" ★"

    printf "  %-25s %-10s %-12s %s\n" "${env_name}${active}" "$py_ver" "${size:-?}" "$env_path"
done <<< "$envs"

echo ""
echo "  ★ = entorno activo actualmente"
echo ""

# ── Detalles de cada entorno ──────────────────────────────────────────────
echo "── PAQUETES PRINCIPALES POR ENTORNO ─────"
echo ""

while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    env_name=$(echo "$line" | awk '{print $1}')
    env_path=$(echo "$line" | awk '{print $NF}')
    [[ "$env_path" == "*" ]] && env_path=$(echo "$line" | awk '{print $2}')

    echo "📦 [$env_name]"

    # Paquetes más relevantes (ML/Data Science y herramientas comunes)
    key_packages=(numpy pandas scipy matplotlib scikit-learn tensorflow pytorch \
                  keras jupyter notebook jupyterlab flask fastapi django \
                  requests sqlalchemy pytest black pylint)

    pip_bin=""
    [[ -f "$env_path/bin/pip" ]]     && pip_bin="$env_path/bin/pip"
    [[ -f "$env_path/bin/pip3" ]]    && pip_bin="$env_path/bin/pip3"

    if [[ -n "$pip_bin" ]]; then
        installed=$("$pip_bin" list --format=columns 2>/dev/null)
        for pkg in "${key_packages[@]}"; do
            ver=$(echo "$installed" | awk -v p="${pkg}" 'tolower($1)==tolower(p){print $2}')
            if [[ -n "$ver" ]]; then
                printf "   • %-20s %s\n" "$pkg" "$ver"
            fi
        done
    fi

    # Contar total de paquetes
    if [[ -n "$pip_bin" ]]; then
        total_pkgs=$("$pip_bin" list 2>/dev/null | tail -n +3 | wc -l | tr -d ' ')
        echo "   Total paquetes instalados: $total_pkgs"
    fi
    echo ""
done <<< "$envs"

echo "======================================"
echo "Uso: $0"
