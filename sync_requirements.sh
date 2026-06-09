#!/bin/bash
# sync_requirements.sh
# Compara requirements.txt con lo instalado en el entorno activo
# Uso: ./sync_requirements.sh [requirements.txt] [--fix]

REQ_FILE="${1:-requirements.txt}"
FIX_MODE="${2:-}"

echo "======================================"
echo " SYNC REQUIREMENTS"
echo "======================================"
echo ""

# Verificar archivo
if [[ ! -f "$REQ_FILE" ]]; then
    echo "Error: no se encontró '$REQ_FILE'"
    echo "Uso: $0 [requirements.txt] [--fix]"
    exit 1
fi

# Verificar pip
if ! command -v pip &>/dev/null && ! command -v pip3 &>/dev/null; then
    echo "Error: pip no está disponible"
    exit 1
fi

PIP=$(command -v pip3 || command -v pip)
ENV_NAME="${CONDA_DEFAULT_ENV:-${VIRTUAL_ENV:-sistema}}"

echo "  Archivo : $REQ_FILE"
echo "  Entorno : $ENV_NAME"
echo "  pip     : $($PIP --version | head -1)"
echo ""

# Obtener paquetes instalados (nombre en minúsculas)
installed=$($PIP list --format=columns 2>/dev/null | tail -n +3 | \
    awk '{print tolower($1) "==" $2}')

missing=()
version_mismatch=()
ok=()

# Comparar línea por línea
while IFS= read -r line; do
    # Ignorar comentarios y líneas vacías
    [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue

    # Extraer nombre y versión requerida
    pkg_name=$(echo "$line" | sed 's/[><=!].*//' | xargs | tr '[:upper:]' '[:lower:]')
    req_ver=$(echo "$line" | grep -oP '[><=!]+[0-9][^\s]*' | head -1)

    # Buscar en instalados
    inst_line=$(echo "$installed" | grep "^${pkg_name}==")

    if [[ -z "$inst_line" ]]; then
        missing+=("$line")
    else
        inst_ver=$(echo "$inst_line" | cut -d= -f3)
        if [[ -n "$req_ver" ]]; then
            # Verificar si la versión instalada cumple el requisito
            req_op=$(echo "$req_ver" | grep -oP '^[><=!]+')
            req_num=$(echo "$req_ver" | grep -oP '[0-9].*')
            if [[ "$req_op" == "==" && "$inst_ver" != "$req_num" ]]; then
                version_mismatch+=("$pkg_name: requerido=$req_num instalado=$inst_ver")
            else
                ok+=("$pkg_name==$inst_ver")
            fi
        else
            ok+=("$pkg_name==$inst_ver")
        fi
    fi
done < "$REQ_FILE"

# ── Reporte ────────────────────────────────────────────────────────────────
echo "── ✅ INSTALADOS CORRECTAMENTE ($((${#ok[@]}))) ──"
for p in "${ok[@]}"; do
    printf "   • %s\n" "$p"
done
echo ""

echo "── ⚠️  VERSIÓN INCORRECTA ($((${#version_mismatch[@]}))) ────"
for p in "${version_mismatch[@]}"; do
    printf "   • %s\n" "$p"
done
echo ""

echo "── ❌ FALTANTES ($((${#missing[@]}))) ──────────────"
for p in "${missing[@]}"; do
    printf "   • %s\n" "$p"
done
echo ""

# ── Paquetes instalados que no están en requirements ──────────────────────
echo "── 🔍 INSTALADOS PERO NO EN requirements ─"
while IFS= read -r inst_pkg; do
    pkg_name=$(echo "$inst_pkg" | cut -d= -f1)
    if ! grep -qi "^${pkg_name}[><=! ]" "$REQ_FILE" 2>/dev/null; then
        printf "   • %s\n" "$inst_pkg"
    fi
done <<< "$installed"
echo ""

# ── Acción de corrección ──────────────────────────────────────────────────
if [[ "$FIX_MODE" == "--fix" ]]; then
    if [[ ${#missing[@]} -gt 0 || ${#version_mismatch[@]} -gt 0 ]]; then
        echo "── Instalando paquetes faltantes/incorrectos ─"
        $PIP install -r "$REQ_FILE"
    else
        echo "✓ Todo está en orden, nada que corregir"
    fi
else
    if [[ ${#missing[@]} -gt 0 || ${#version_mismatch[@]} -gt 0 ]]; then
        echo "  Ejecuta con --fix para instalar automáticamente:"
        echo "  $0 $REQ_FILE --fix"
    fi
fi
