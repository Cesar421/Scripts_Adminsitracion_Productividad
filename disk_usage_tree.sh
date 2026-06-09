#!/bin/bash
# disk_usage_tree.sh
# Muestra qué carpetas consumen más espacio, ordenadas de mayor a menor

TARGET="${1:-.}"
DEPTH="${2:-2}"
TOP="${3:-20}"

# Convertir ruta relativa a absoluta
if [[ "$TARGET" != /* ]]; then
    TARGET="$(cd "$TARGET" && pwd)"
fi

echo "======================================"
echo " USO DE DISCO — $TARGET"
echo " Profundidad: $DEPTH  |  Top: $TOP carpetas"
echo "======================================"
echo ""

# Total del directorio
total=$(du -sh "$TARGET" 2>/dev/null | cut -f1)
echo "  Total en '$TARGET': $total"
echo ""

# Top N subdirectorios por tamaño
echo "── TOP $TOP CARPETAS MÁS GRANDES ────────"
printf "  %10s  %s\n" "TAMAÑO" "RUTA"
printf "  %10s  %s\n" "----------" "$(printf -- '-%.0s' {1..50})"

du -h --max-depth="$DEPTH" "$TARGET" 2>/dev/null \
    | sort -rh \
    | grep -v "^[0-9.]*[KMG]*	$TARGET$" \
    | head -"$TOP" \
    | while IFS=$'\t' read -r size path; do
        # Mostrar ruta relativa al target
        rel="${path#$TARGET/}"
        printf "  %10s  %s\n" "$size" "$rel"
    done

echo ""

# Archivos más grandes en el directorio
echo "── TOP 10 ARCHIVOS MÁS GRANDES ─────────"
printf "  %10s  %s\n" "TAMAÑO" "ARCHIVO"
printf "  %10s  %s\n" "----------" "$(printf -- '-%.0s' {1..50})"

find "$TARGET" -maxdepth "$((DEPTH + 1))" -type f 2>/dev/null \
    | xargs du -h 2>/dev/null \
    | sort -rh \
    | head -10 \
    | while IFS=$'\t' read -r size path; do
        rel="${path#$TARGET/}"
        printf "  %10s  %s\n" "$size" "$rel"
    done

echo ""
echo "Uso: $0 [directorio] [profundidad=2] [top=20]"
