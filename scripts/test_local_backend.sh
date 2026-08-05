#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(dirname "$SCRIPT_DIR")
BACKEND_DIR="$PROJECT_DIR/backend"

if [ ! -x "$BACKEND_DIR/.venv/bin/python" ]; then
  echo "ERROR: Falta backend/.venv. Ejecute ./scripts/setup_local.sh primero."
  exit 1
fi

cd "$BACKEND_DIR"
. .venv/bin/activate
python -m pytest -q
python -m ruff check app tests
