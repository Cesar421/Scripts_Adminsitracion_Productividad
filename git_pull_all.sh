#!/bin/bash
# git_pull_all.sh

ROOT_DIR="${1:-$HOME/projects}"

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

    branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "detached")

    printf "%-40s (%s) ... " "$name" "$branch"

    result=$(git pull --rebase 2>&1)
    exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        if echo "$result" | grep -q "Already up to date"; then
            echo "OK - Ya al dia"
        else
            echo "OK - Actualizado"
        fi
    else
        echo "FALLO"
        echo "   => $(echo "$result" | tail -1)"
    fi
done