#!/bin/bash
# clean_pycache.sh
# Elimina recursivamente __pycache__, .pyc, .pyo y archivos temporales de Python
# Uso: ./clean_pycache.sh [directorio] [--dry-run]

TARGET="${1:-.}"
DRY_RUN="${2:-}"

if [[ "$TARGET" != /* ]]; then
    TARGET="$(cd "$TARGET" && pwd)"
fi

echo "======================================"
echo " LIMPIEZA DE CACHÉ PYTHON"
echo " Directorio: $TARGET"
[[ "$DRY_RUN" == "--dry-run" ]] && echo " MODO: DRY-RUN (sin borrar nada)"
echo "======================================"
echo ""

count_dirs=0
count_files=0
total_size=0

# ── __pycache__ directories ────────────────────────────────────────────────
echo "── Carpetas __pycache__ ─────────────────"
while IFS= read -r dir; do
    size=$(du -sb "$dir" 2>/dev/null | awk '{print $1}')
    total_size=$((total_size + ${size:-0}))
    count_dirs=$((count_dirs + 1))
    echo "   $dir"
    if [[ "$DRY_RUN" != "--dry-run" ]]; then
        rm -rf "$dir"
    fi
done < <(find "$TARGET" -type d -name "__pycache__" 2>/dev/null)

echo "   ($count_dirs carpetas)"
echo ""

# ── Archivos .pyc y .pyo ──────────────────────────────────────────────────
echo "── Archivos .pyc / .pyo ─────────────────"
while IFS= read -r file; do
    size=$(du -sb "$file" 2>/dev/null | awk '{print $1}')
    total_size=$((total_size + ${size:-0}))
    count_files=$((count_files + 1))
    echo "   $file"
    if [[ "$DRY_RUN" != "--dry-run" ]]; then
        rm -f "$file"
    fi
done < <(find "$TARGET" -type f \( -name "*.pyc" -o -name "*.pyo" \) 2>/dev/null)

echo "   ($count_files archivos)"
echo ""

# ── Archivos .pytest_cache ────────────────────────────────────────────────
echo "── Carpetas .pytest_cache ───────────────"
pytest_count=0
while IFS= read -r dir; do
    size=$(du -sb "$dir" 2>/dev/null | awk '{print $1}')
    total_size=$((total_size + ${size:-0}))
    pytest_count=$((pytest_count + 1))
    echo "   $dir"
    if [[ "$DRY_RUN" != "--dry-run" ]]; then
        rm -rf "$dir"
    fi
done < <(find "$TARGET" -type d -name ".pytest_cache" 2>/dev/null)
echo "   ($pytest_count carpetas)"
echo ""

# ── Carpetas .mypy_cache ──────────────────────────────────────────────────
echo "── Carpetas .mypy_cache ─────────────────"
mypy_count=0
while IFS= read -r dir; do
    size=$(du -sb "$dir" 2>/dev/null | awk '{print $1}')
    total_size=$((total_size + ${size:-0}))
    mypy_count=$((mypy_count + 1))
    echo "   $dir"
    if [[ "$DRY_RUN" != "--dry-run" ]]; then
        rm -rf "$dir"
    fi
done < <(find "$TARGET" -type d -name ".mypy_cache" 2>/dev/null)
echo "   ($mypy_count carpetas)"
echo ""

# ── Resumen ────────────────────────────────────────────────────────────────
echo "======================================"
freed_mb=$(echo "scale=2; $total_size / 1048576" | bc 2>/dev/null || echo "?")
echo " Carpetas __pycache__  : $count_dirs"
echo " Archivos .pyc/.pyo    : $count_files"
echo " Caches de test/mypy   : $((pytest_count + mypy_count))"
echo " Espacio liberado      : ~${freed_mb} MB"
if [[ "$DRY_RUN" == "--dry-run" ]]; then
    echo ""
    echo " Ejecuta sin --dry-run para borrar:"
    echo " $0 $TARGET"
fi
echo "======================================"
