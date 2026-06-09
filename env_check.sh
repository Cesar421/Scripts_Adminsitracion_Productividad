#!/bin/bash
# env_check.sh
# Verifica que las herramientas del entorno de desarrollo estén instaladas
# Uso: ./env_check.sh [--json]

JSON_MODE="${1:-}"

echo "======================================"
echo " ENV CHECK — $(date '+%Y-%m-%d %H:%M:%S')"
echo "======================================"
echo ""

ok=0
warn=0
fail=0

check() {
    local name="$1"
    local cmd="$2"
    local min_ver="${3:-}"
    local category="${4:-General}"

    local ver status

    if command -v "$cmd" &>/dev/null; then
        ver=$("$cmd" --version 2>&1 | head -1 | grep -oP '[0-9]+\.[0-9]+\.?[0-9]*' | head -1)
        status="OK"
        ok=$((ok + 1))
        printf "  ✅ %-20s %-15s %s\n" "$name" "${ver:-disponible}" "$(which "$cmd")"
    else
        status="FALTA"
        fail=$((fail + 1))
        printf "  ❌ %-20s %-15s %s\n" "$name" "no encontrado" ""
    fi
}

check_optional() {
    local name="$1"
    local cmd="$2"

    if command -v "$cmd" &>/dev/null; then
        ver=$("$cmd" --version 2>&1 | head -1 | grep -oP '[0-9]+\.[0-9]+\.?[0-9]*' | head -1)
        ok=$((ok + 1))
        printf "  ✅ %-20s %-15s %s\n" "$name" "${ver:-disponible}" "$(which "$cmd")"
    else
        warn=$((warn + 1))
        printf "  ⚠️  %-20s %-15s %s\n" "$name" "no encontrado" "(opcional)"
    fi
}

# ── Control de versiones ───────────────────────────────────────────────────
echo "── CONTROL DE VERSIONES ─────────────────"
check "git"            "git"
check_optional "gh"   "gh"    # GitHub CLI
echo ""

# ── Python ────────────────────────────────────────────────────────────────
echo "── PYTHON ───────────────────────────────"
check          "python3"      "python3"
check_optional "python"       "python"
check          "pip / pip3"   "pip3"
check_optional "conda"        "conda"
check_optional "pipenv"       "pipenv"
check_optional "poetry"       "poetry"
check_optional "pytest"       "pytest"
check_optional "black"        "black"
check_optional "pylint"       "pylint"
check_optional "mypy"         "mypy"
echo ""

# ── Node.js ────────────────────────────────────────────────────────────────
echo "── NODE.JS / JS ─────────────────────────"
check_optional "node"         "node"
check_optional "npm"          "npm"
check_optional "yarn"         "yarn"
check_optional "pnpm"         "pnpm"
echo ""

# ── Contenedores ──────────────────────────────────────────────────────────
echo "── CONTENEDORES ─────────────────────────"
check_optional "docker"       "docker"
check_optional "docker-compose" "docker-compose"
check_optional "kubectl"      "kubectl"
echo ""

# ── Herramientas del sistema ──────────────────────────────────────────────
echo "── HERRAMIENTAS SISTEMA ─────────────────"
check          "curl"         "curl"
check          "wget"         "wget"
check          "ssh"          "ssh"
check          "make"         "make"
check_optional "jq"           "jq"
check_optional "htop"         "htop"
check_optional "tree"         "tree"
check_optional "bc"           "bc"
echo ""

# ── Editores ──────────────────────────────────────────────────────────────
echo "── EDITORES / IDEs ──────────────────────"
check_optional "code"         "code"    # VS Code
check_optional "vim"          "vim"
check_optional "nvim"         "nvim"
echo ""

# ── Info del entorno ──────────────────────────────────────────────────────
echo "── ENTORNO ACTIVO ───────────────────────"
printf "  %-20s %s\n" "SHELL:" "$SHELL"
printf "  %-20s %s\n" "OS:" "$(uname -s) $(uname -r)"
printf "  %-20s %s\n" "Arch:" "$(uname -m)"
printf "  %-20s %s\n" "Usuario:" "$USER"
printf "  %-20s %s\n" "Home:" "$HOME"
[[ -n "$CONDA_DEFAULT_ENV" ]] && printf "  %-20s %s\n" "Conda env:" "$CONDA_DEFAULT_ENV"
[[ -n "$VIRTUAL_ENV" ]]       && printf "  %-20s %s\n" "venv:" "$VIRTUAL_ENV"
echo ""

# ── Resumen ────────────────────────────────────────────────────────────────
echo "======================================"
printf "  ✅ Disponibles : %d\n" "$ok"
printf "  ⚠️  Opcionales  : %d\n" "$warn"
printf "  ❌ Faltantes   : %d\n" "$fail"
echo "======================================"
