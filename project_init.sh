#!/bin/bash
# project_init.sh
# Crea la estructura base de un nuevo proyecto con git, .gitignore y README
# Uso: ./project_init.sh <nombre_proyecto> [tipo: python|node|general] [directorio_destino]

PROJECT_NAME="${1:-}"
PROJECT_TYPE="${2:-python}"
DEST_DIR="${3:-.}"

if [[ -z "$PROJECT_NAME" ]]; then
    echo "Uso: $0 <nombre_proyecto> [tipo: python|node|general] [directorio_destino]"
    echo ""
    echo "Tipos disponibles:"
    echo "  python   — src/, tests/, requirements.txt, .gitignore Python"
    echo "  node     — src/, tests/, package.json, .gitignore Node"
    echo "  general  — src/, docs/, .gitignore básico"
    exit 1
fi

if [[ "$DEST_DIR" != /* ]]; then
    DEST_DIR="$(cd "$DEST_DIR" && pwd)"
fi

PROJECT_PATH="$DEST_DIR/$PROJECT_NAME"

echo "======================================"
echo " PROJECT INIT"
echo " Nombre : $PROJECT_NAME"
echo " Tipo   : $PROJECT_TYPE"
echo " Destino: $PROJECT_PATH"
echo "======================================"
echo ""

# Verificar que no exista ya
if [[ -d "$PROJECT_PATH" ]]; then
    echo "Error: '$PROJECT_PATH' ya existe"
    exit 1
fi

step() { echo "  ✓ $1"; }

# ── Crear estructura de carpetas ──────────────────────────────────────────
mkdir -p "$PROJECT_PATH"
step "Carpeta raíz creada"

case "$PROJECT_TYPE" in
    python)
        mkdir -p "$PROJECT_PATH/src/$PROJECT_NAME"
        mkdir -p "$PROJECT_PATH/tests"
        mkdir -p "$PROJECT_PATH/docs"
        mkdir -p "$PROJECT_PATH/data"
        touch "$PROJECT_PATH/src/$PROJECT_NAME/__init__.py"
        touch "$PROJECT_PATH/src/$PROJECT_NAME/main.py"
        touch "$PROJECT_PATH/tests/__init__.py"
        touch "$PROJECT_PATH/tests/test_main.py"
        step "Estructura Python creada (src/, tests/, docs/, data/)"
        ;;
    node)
        mkdir -p "$PROJECT_PATH/src"
        mkdir -p "$PROJECT_PATH/tests"
        mkdir -p "$PROJECT_PATH/public"
        touch "$PROJECT_PATH/src/index.js"
        step "Estructura Node creada (src/, tests/, public/)"
        ;;
    general|*)
        mkdir -p "$PROJECT_PATH/src"
        mkdir -p "$PROJECT_PATH/docs"
        mkdir -p "$PROJECT_PATH/tests"
        step "Estructura general creada (src/, docs/, tests/)"
        ;;
esac

# ── .gitignore ────────────────────────────────────────────────────────────
case "$PROJECT_TYPE" in
    python)
cat > "$PROJECT_PATH/.gitignore" << 'EOF'
# Python
__pycache__/
*.py[cod]
*.pyo
*.pyd
.Python
*.egg
*.egg-info/
dist/
build/
.eggs/
.venv/
venv/
env/
.env
*.env

# Pytest
.pytest_cache/
.coverage
htmlcov/

# Jupyter
.ipynb_checkpoints/
*.ipynb_checkpoints

# IDEs
.vscode/
.idea/
*.swp

# Data / outputs
data/raw/
*.csv
*.log
EOF
        ;;
    node)
cat > "$PROJECT_PATH/.gitignore" << 'EOF'
# Node
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
.pnpm-debug.log*
dist/
build/
.cache/
.env
.env.local
.env.*.local

# IDEs
.vscode/
.idea/
*.swp

# OS
.DS_Store
Thumbs.db
EOF
        ;;
    *)
cat > "$PROJECT_PATH/.gitignore" << 'EOF'
# Generales
*.log
*.tmp
*.bak
.env
.DS_Store
Thumbs.db

# IDEs
.vscode/
.idea/
*.swp
EOF
        ;;
esac
step ".gitignore creado"

# ── README.md ─────────────────────────────────────────────────────────────
cat > "$PROJECT_PATH/README.md" << EOF
# $PROJECT_NAME

> Creado el $(date '+%Y-%m-%d') con project_init.sh

## Descripción

_Describe aquí el propósito del proyecto._

## Instalación

\`\`\`bash
# Clonar repositorio
git clone <url>
cd $PROJECT_NAME
\`\`\`

EOF

if [[ "$PROJECT_TYPE" == "python" ]]; then
cat >> "$PROJECT_PATH/README.md" << 'EOF'
```bash
# Crear entorno virtual
python -m venv venv
source venv/bin/activate   # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

## Uso

```bash
python src/main.py
```

## Tests

```bash
pytest tests/
```
EOF

elif [[ "$PROJECT_TYPE" == "node" ]]; then
cat >> "$PROJECT_PATH/README.md" << 'EOF'
```bash
npm install
```

## Uso

```bash
npm start
```

## Tests

```bash
npm test
```
EOF
fi
step "README.md creado"

# ── Archivos específicos por tipo ─────────────────────────────────────────
if [[ "$PROJECT_TYPE" == "python" ]]; then
    cat > "$PROJECT_PATH/requirements.txt" << 'EOF'
# Dependencias del proyecto
# pytest>=7.0
# requests>=2.28
EOF
    step "requirements.txt creado"

    cat > "$PROJECT_PATH/src/$PROJECT_NAME/main.py" << EOF
#!/usr/bin/env python3
"""Módulo principal de $PROJECT_NAME."""


def main():
    print("Hola desde $PROJECT_NAME!")


if __name__ == "__main__":
    main()
EOF

    cat > "$PROJECT_PATH/tests/test_main.py" << EOF
"""Tests para el módulo principal."""
from src.${PROJECT_NAME//-/_}.main import main


def test_main():
    """Test básico de main."""
    assert main is not None
EOF
    step "main.py y test_main.py creados"

elif [[ "$PROJECT_TYPE" == "node" ]]; then
    cat > "$PROJECT_PATH/package.json" << EOF
{
  "name": "$PROJECT_NAME",
  "version": "1.0.0",
  "description": "",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "test": "echo \"Sin tests configurados\" && exit 0"
  },
  "keywords": [],
  "author": "",
  "license": "MIT"
}
EOF
    step "package.json creado"
fi

# ── Git init ───────────────────────────────────────────────────────────────
cd "$PROJECT_PATH" || exit 1
git init -q
git add .
git commit -q -m "chore: initial project structure"
step "Repositorio git inicializado + commit inicial"

echo ""
echo "======================================"
echo " ✅ Proyecto '$PROJECT_NAME' listo"
echo "======================================"
echo ""
echo "  cd $PROJECT_PATH"
[[ "$PROJECT_TYPE" == "python" ]] && echo "  python src/$PROJECT_NAME/main.py"
[[ "$PROJECT_TYPE" == "node"   ]] && echo "  npm start"
echo ""
