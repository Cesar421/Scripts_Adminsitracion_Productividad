#!/bin/bash
# count_commits.sh
# Analiza estadísticas de commits en todos los repositorios

ROOT_DIR="${1:-.}"
SINCE="${2:-all}"

# Convertir ruta relativa a absoluta
if [[ "$ROOT_DIR" != /* ]]; then
    ROOT_DIR="$(cd "$ROOT_DIR" && pwd)"
fi

TMPFILE=$(mktemp /tmp/repo_data.XXXXXX)

echo "======================================"
echo "Análisis de commits en: $ROOT_DIR"
if [[ "$SINCE" == "all" ]]; then
    echo "Período: TODOS los commits"
else
    echo "Período: $SINCE"
fi
echo "======================================"
echo ""

# ── Primera pasada: mostrar detalles por repo ──────────────────────────────
find "$ROOT_DIR" -maxdepth 3 -name ".git" -type d | sort | while IFS= read -r gitdir; do
    repo="${gitdir%/.git}"
    name=$(basename "$repo")

    cd "$repo" || continue

    if ! git remote get-url origin &>/dev/null; then
        continue
    fi

    if [[ "$SINCE" == "all" ]]; then
        commit_count=$(git log --oneline 2>/dev/null | wc -l | tr -d ' ')
    else
        commit_count=$(git log --since="$SINCE" --oneline 2>/dev/null | wc -l | tr -d ' ')
    fi

    [[ $commit_count -eq 0 ]] && continue

    first_date=$(git log --reverse --format="%as" 2>/dev/null | head -1)
    last_date=$(git log -1 --format="%as" 2>/dev/null)

    echo "📦 [$name]"
    printf "   %-20s %s\n" "Total commits:" "$commit_count"
    printf "   %-20s %s\n" "Primer commit:" "$first_date"
    printf "   %-20s %s\n" "Último commit:"  "$last_date"
    echo "   Por autor:"

    if [[ "$SINCE" == "all" ]]; then
        git log --format="%an" --no-merges 2>/dev/null
    else
        git log --since="$SINCE" --format="%an" --no-merges 2>/dev/null
    fi | sort | uniq -c | sort -rn | while read -r count author; do
        printf "     • %-30s %d commits\n" "$author" "$count"
    done

    last_commit=$(git log -1 --format="%h - %an (%ar)" 2>/dev/null)
    printf "   %-20s %s\n" "Último hash:" "$last_commit"
    echo ""

    # Guardar para gráfica en archivo separado
    echo "$name|$commit_count|$first_date|$last_date" >> "$TMPFILE"
done

# ── Resumen y gráfica ──────────────────────────────────────────────────────
echo "======================================"
echo "RESUMEN Y GRÁFICA"
echo "======================================"
echo ""

if [[ ! -s "$TMPFILE" ]]; then
    echo "⚠️  No se encontraron repositorios en: $ROOT_DIR"
    rm -f "$TMPFILE"
    exit 0
fi

total_repos=$(wc -l < "$TMPFILE" | tr -d ' ')
total_commits=$(awk -F'|' '{s+=$2} END {print s}' "$TMPFILE")

echo "✓ Repositorios encontrados : $total_repos"
echo "✓ Commits totales          : $total_commits"
echo ""

# Máximo de commits para escalar la barra a 40 caracteres
max_commits=$(awk -F'|' 'BEGIN{m=0} {if($2>m) m=$2} END{print m}' "$TMPFILE")

echo "📊 COMMITS POR REPOSITORIO:"
echo ""
printf "%-35s  %-40s  %6s\n" "REPOSITORIO" "COMMITS" "TOTAL"
printf "%-35s  %-40s  %6s\n" "$(printf -- '-%.0s' {1..35})" "$(printf -- '-%.0s' {1..40})" "------"

while IFS='|' read -r name commits first_date last_date; do
    # Escalar barra a máximo 40 chars
    if [[ $max_commits -gt 0 ]]; then
        bar_width=$(( commits * 40 / max_commits ))
    else
        bar_width=0
    fi
    [[ $bar_width -lt 1 && $commits -gt 0 ]] && bar_width=1

    # Construir barra y rellenar espacios manualmente (█ = 3 bytes, printf no alinea bien)
    bar=""
    for ((i=0; i<bar_width; i++)); do bar+="█"; done
    padding=$(( 40 - bar_width ))
    spaces=$(printf '%*s' "$padding" "")

    printf "%-35s  %s%s  %6d\n" "$name" "$bar" "$spaces" "$commits"
done < "$TMPFILE"

echo ""
echo "📅 LÍNEA DE TIEMPO GLOBAL:"
echo ""

earliest=$(awk -F'|' 'BEGIN{d=""} {if(d=="" || $3<d) d=$3} END{print d}' "$TMPFILE")
latest=$(awk -F'|'   'BEGIN{d=""} {if(d=="" || $4>d) d=$4} END{print d}' "$TMPFILE")

printf "   %-25s %s\n" "Primer commit (global):" "$earliest"
printf "   %-25s %s\n" "Último commit (global):" "$latest"
echo ""

echo "📋 TABLA DETALLADA:"
echo ""
printf "%-35s  %8s  %12s  %12s\n" "REPOSITORIO" "COMMITS" "PRIMER" "ÚLTIMO"
printf "%-35s  %8s  %12s  %12s\n" "$(printf -- '-%.0s' {1..35})" "--------" "------------" "------------"

while IFS='|' read -r name commits first_date last_date; do
    printf "%-35s  %8d  %12s  %12s\n" "$name" "$commits" "$first_date" "$last_date"
done < "$TMPFILE"

echo ""
rm -f "$TMPFILE"

