#!/bin/bash
# git_push_all.sh

ROOT_DIR="${1:-$HOME/projects}"
COMMIT_MSG="${2:-"auto: sync $(date '+%Y-%m-%d %H:%M')"}"

echo "Buscando repos en: $ROOT_DIR"
echo ""

find "$ROOT_DIR" -maxdepth 3 -name ".git" -type d | sort | while read gitdir; do
    repo="${gitdir%/.git}"
    name=$(basename "$repo")

    cd "$repo" || continue

    if ! git remote get-url origin &>/dev/null; then
        echo "[$name] Sin remote origin -- omitido"
        continue
    fi

    if [[ -z "$(git status --porcelain)" ]]; then
        echo "[$name] Sin cambios"
        continue
    fi

    branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "detached")

    git add -A
    git commit -m "$COMMIT_MSG" &>/dev/null

    printf "%-40s (%s) ... " "$name" "$branch"

    result=$(git push origin "$branch" 2>&1)
    exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        echo "OK - Push exitoso"
    else
        echo "FALLO"
        echo "   => $(echo "$result" | tail -1)"
    fi
done