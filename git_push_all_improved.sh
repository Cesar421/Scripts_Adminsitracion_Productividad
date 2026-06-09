#!/bin/bash
# git_push_all.sh (MEJORADO)
# Push a múltiples repos con validación y opciones

ROOT_DIR="${1:-.}"
COMMIT_MSG="${2:-}"
INTERACTIVE=false
DRY_RUN=false
SKIP_PUSH=false
SMART_MSG=false

# Procesar flags
while [[ "$1" == -* ]]; do
    case "$1" in
        --interactive|-i) INTERACTIVE=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --skip-push) SKIP_PUSH=true; shift ;;
        --smart) SMART_MSG=true; shift ;;
        --help|-h)
            echo "Uso: $0 [directorio] [mensaje] [opciones]"
            echo ""
            echo "Opciones:"
            echo "  --interactive, -i   Pedir confirmación y mostrar cambios por repo"
            echo "  --dry-run           Ver qué haría sin hacer nada"
            echo "  --skip-push         Solo hacer commit, sin push"
            echo "  --smart             Auto-generar mensaje basado en cambios"
            echo "  --help, -h          Mostrar esta ayuda"
            echo ""
            echo "Ejemplos:"
            echo "  $0 ~/projects --interactive"
            echo "  $0 ~/projects 'fix: bug fixes' --dry-run"
            echo "  $0 . --smart --skip-push"
            exit 0
            ;;
        *) ROOT_DIR="$1"; shift ;;
    esac
done

# Validar directorio
if [[ ! -d "$ROOT_DIR" ]]; then
    echo "❌ Directorio no encontrado: $ROOT_DIR"
    exit 1
fi

echo -e "\n${CYAN}🔍 Buscando repositorios en: $ROOT_DIR${NC}\n"

count=0
success=0
failed=0
skipped=0

find "$ROOT_DIR" -maxdepth 3 -name ".git" -type d | sort | while read gitdir; do
    repo="${gitdir%/.git}"
    name=$(basename "$repo")
    ((count++))

    cd "$repo" || continue

    # Verificar si tiene remote
    if ! git remote get-url origin &>/dev/null; then
        echo "⚠️  [$name] Sin remote origin -- omitido"
        ((skipped++))
        continue
    fi

    # Verificar si hay cambios
    status=$(git status --porcelain)
    if [[ -z "$status" ]]; then
        echo "✓ [$name] Sin cambios"
        ((skipped++))
        continue
    fi

    branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "detached")

    # Modo interactivo
    if [[ "$INTERACTIVE" == true ]]; then
        echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        printf "${BLUE}📁 Repositorio: ${NC}$name ($branch)\n\n"
        
        echo -e "${MAGENTA}Cambios:${NC}"
        echo "$status" | sed 's/^/  /'
        echo ""
        
        read -p "¿Incluir en commit? (s/n/ver): " choice
        case $choice in
            v|ver) git diff --no-index /dev/null /dev/null 2>/dev/null || git status -vv; read -p "¿Continuar? (s/n): " choice ;;
        esac
        
        if [[ ! "$choice" =~ ^[sS]$ ]]; then
            echo "  ⏭️  Omitido"
            ((skipped++))
            continue
        fi
    fi

    # Determinar mensaje de commit
    if [[ -z "$COMMIT_MSG" ]]; then
        if [[ "$SMART_MSG" == true ]]; then
            # Generar mensaje smart basado en cambios
            local file_count=$(echo "$status" | wc -l)
            local added=$(echo "$status" | grep "^A" | wc -l)
            local modified=$(echo "$status" | grep "^M" | wc -l)
            local deleted=$(echo "$status" | grep "^D" | wc -l)
            
            msg_parts=()
            [[ $modified -gt 0 ]] && msg_parts+=("$modified modified")
            [[ $added -gt 0 ]] && msg_parts+=("$added added")
            [[ $deleted -gt 0 ]] && msg_parts+=("$deleted deleted")
            
            msg="chore: $(IFS=', '; echo "${msg_parts[*]}")"
        else
            msg="auto: sync $(date '+%Y-%m-%d %H:%M')"
        fi
    else
        msg="$COMMIT_MSG"
    fi

    # Hacer commit
    echo -n "  Commit: "
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] '$msg'"
    else
        if git add -A && git commit -m "$msg" &>/dev/null; then
            echo "✓ '$msg'"
        else
            echo "❌ Error en commit"
            ((failed++))
            continue
        fi
    fi

    # Skip push si se indica
    if [[ "$SKIP_PUSH" == true ]]; then
        echo "  Push: ⏭️  Omitido (--skip-push)"
        ((success++))
        continue
    fi

    # Push
    echo -n "  Push: "
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] origin/$branch"
    else
        result=$(git push origin "$branch" 2>&1)
        exit_code=$?
        
        if [[ $exit_code -eq 0 ]]; then
            echo "✓ origin/$branch"
            ((success++))
        else
            echo "❌ Fallo"
            echo "     Error: $(echo "$result" | tail -1 | cut -c1-50)"
            ((failed++))
        fi
    fi
done

# Resumen
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}[DRY-RUN] Resumen:${NC}"
else
    echo -e "${GREEN}✓ Operación completada${NC}"
fi
echo "  Total repos: $count"
echo "  ✓ Exitosos: $success"
[[ $failed -gt 0 ]] && echo "  ❌ Fallidos: $failed"
echo "  ⏭️  Omitidos: $skipped"
echo ""
