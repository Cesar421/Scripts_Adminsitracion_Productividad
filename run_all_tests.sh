#!/bin/bash
# run_all_tests.sh
# Ejecuta tests en todos los proyectos de una carpeta y reporta resultados
# Uso: ./run_all_tests.sh [directorio] [--verbose]

ROOT_DIR="${1:-.}"
VERBOSE="${2:-}"

if [[ "$ROOT_DIR" != /* ]]; then
    ROOT_DIR="$(cd "$ROOT_DIR" && pwd)"
fi

LOG_FILE="/tmp/test_results_$(date +%Y%m%d_%H%M%S).log"

echo "======================================"
echo " RUN ALL TESTS"
echo " Directorio: $ROOT_DIR"
echo " Log: $LOG_FILE"
echo "======================================"
echo ""

passed=0
failed=0
skipped=0
no_tests=0

detect_test_runner() {
    local dir="$1"
    if [[ -f "$dir/pytest.ini" || -f "$dir/setup.cfg" || -f "$dir/pyproject.toml" ]]; then
        echo "pytest"
    elif [[ -f "$dir/package.json" ]] && grep -q '"test"' "$dir/package.json" 2>/dev/null; then
        echo "npm"
    elif [[ -f "$dir/Makefile" ]] && grep -q "^test:" "$dir/Makefile" 2>/dev/null; then
        echo "make"
    elif find "$dir" -maxdepth 2 -name "test_*.py" -o -name "*_test.py" 2>/dev/null | grep -q .; then
        echo "pytest"
    else
        echo "none"
    fi
}

run_tests() {
    local dir="$1"
    local runner="$2"
    local name="$3"

    case "$runner" in
        pytest)
            if command -v pytest &>/dev/null; then
                output=$(cd "$dir" && pytest --tb=short -q 2>&1)
                exit_code=$?
            else
                output="pytest no encontrado"
                exit_code=127
            fi
            ;;
        npm)
            output=$(cd "$dir" && npm test --silent 2>&1)
            exit_code=$?
            ;;
        make)
            output=$(cd "$dir" && make test 2>&1)
            exit_code=$?
            ;;
        *)
            exit_code=99
            output=""
            ;;
    esac

    echo "$output"
    return $exit_code
}

find "$ROOT_DIR" -maxdepth 3 -name ".git" -type d | sort | while IFS= read -r gitdir; do
    repo="${gitdir%/.git}"
    name=$(basename "$repo")

    runner=$(detect_test_runner "$repo")

    if [[ "$runner" == "none" ]]; then
        printf "  %-35s ⚪ Sin tests\n" "$name"
        echo "NO_TESTS|$name" >> "$LOG_FILE"
        continue
    fi

    printf "  %-35s %-10s ... " "$name" "[$runner]"

    output=$(run_tests "$repo" "$runner" "$name")
    exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        # Extraer número de tests pasados
        if [[ "$runner" == "pytest" ]]; then
            summary=$(echo "$output" | grep -E "passed|failed|error" | tail -1)
        else
            summary="OK"
        fi
        printf "✅ PASÓ   %s\n" "$summary"
        echo "PASS|$name|$runner|$summary" >> "$LOG_FILE"
        if [[ "$VERBOSE" == "--verbose" ]]; then
            echo "$output" | sed 's/^/     /'
        fi
    elif [[ $exit_code -eq 127 ]]; then
        printf "⚠️  Sin runner\n"
        echo "SKIP|$name|$runner|runner no instalado" >> "$LOG_FILE"
    else
        summary=$(echo "$output" | grep -E "failed|error|FAIL|ERROR" | tail -1)
        printf "❌ FALLÓ  %s\n" "$summary"
        echo "FAIL|$name|$runner|$summary" >> "$LOG_FILE"
        if [[ "$VERBOSE" == "--verbose" ]]; then
            echo "$output" | sed 's/^/     /'
        fi
    fi
done

echo ""
echo "======================================"
echo " RESUMEN"
echo "======================================"

if [[ -f "$LOG_FILE" ]]; then
    pass_count=$(grep -c "^PASS" "$LOG_FILE" 2>/dev/null || echo 0)
    fail_count=$(grep -c "^FAIL" "$LOG_FILE" 2>/dev/null || echo 0)
    skip_count=$(grep -c "^SKIP\|^NO_TESTS" "$LOG_FILE" 2>/dev/null || echo 0)

    echo "  ✅ Pasaron  : $pass_count"
    echo "  ❌ Fallaron : $fail_count"
    echo "  ⚪ Sin tests : $skip_count"

    if [[ $fail_count -gt 0 ]]; then
        echo ""
        echo "── Proyectos con fallos ─────────────────"
        grep "^FAIL" "$LOG_FILE" | while IFS='|' read -r status name runner msg; do
            echo "  • $name ($runner): $msg"
        done
    fi
fi

echo ""
echo "Log completo: $LOG_FILE"
