#!/bin/bash
# git_push_all.sh
# Push automático a múltiples repositorios Git

set -euo pipefail

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

ROOT_DIR="${1:-$HOME/projects}"
COMMIT_MSG="${2:-"auto: sync $(date '+%Y-%m-%d %H:%M')"}"

# Validar directorio
if [[ ! -d "$ROOT_DIR" ]]; then
    echo -e "${RED}Error: directorio no encontrado: $ROOT_DIR${NC}" >&2
    exit 1
fi

echo -e "\n${CYAN}Buscando repos en: $ROOT_DIR${NC}\n"

count=0
success=0
failed=0
skipped=0

while IFS= read -r gitdir; do
    repo="${gitdir%/.git}"
    name=$(basename "$repo")
    ((count++)) || true

    cd "$repo" || continue

    # Sin remote origin
    if ! git remote get-url origin &>/dev/null; then
        echo -e "${YELLOW}⚠  [$name] Sin remote origin — omitido${NC}"
        ((skipped++)) || true
        continue
    fi

    # Sin cambios
    if [[ -z "$(git status --porcelain)" ]]; then
        echo -e "${GRAY}–  [$name] Sin cambios${NC}"
        ((skipped++)) || true
        continue
    fi

    branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "detached")

    # Commit
    git add -A
    commit_out=$(git commit -m "$COMMIT_MSG" 2>&1)
    commit_code=$?
    if [[ $commit_code -ne 0 ]]; then
        echo -e "${RED}✗  [$name] Commit fallido${NC}"
        echo -e "${GRAY}   => $commit_out${NC}"
        ((failed++)) || true
        continue
    fi

    # Push
    printf "   %-38s (%s) ... " "$name" "$branch"
    push_out=$(git push origin "$branch" 2>&1)
    push_code=$?

    if [[ $push_code -eq 0 ]]; then
        echo -e "${GREEN}✓ Push exitoso${NC}"
        ((success++)) || true
    else
        echo -e "${RED}✗ FALLO${NC}"
        echo -e "${GRAY}   => $(echo "$push_out" | tail -3 | sed 's/^/   /')${NC}"
        ((failed++)) || true
    fi

done < <(find "$ROOT_DIR" -maxdepth 3 -name ".git" -type d | sort)

# Resumen
echo ""
echo -e "──────────────────────────────────────"
echo -e "  Repos encontrados : $count"
echo -e "  ${GREEN}Push exitosos     : $success${NC}"
echo -e "  ${YELLOW}Sin cambios       : $skipped${NC}"
echo -e "  ${RED}Fallidos          : $failed${NC}"
echo -e "──────────────────────────────────────"
echo ""
echo -e "${GRAY}Uso: $0 [directorio] [\"mensaje commit\"]${NC}"