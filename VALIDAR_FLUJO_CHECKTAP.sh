#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$ROOT_DIR/scripts/validar_flujo_completo.py"

if [[ ! -f "$SCRIPT_PATH" ]]; then
  echo "ERROR: No se encontro $SCRIPT_PATH" >&2
  exit 1
fi

if [[ -x "$ROOT_DIR/backend/.venv/bin/python" ]]; then
  PYTHON="$ROOT_DIR/backend/.venv/bin/python"
elif command -v python3 >/dev/null 2>&1; then
  PYTHON="$(command -v python3)"
else
  echo "ERROR: Python 3 no esta disponible." >&2
  exit 1
fi

cd "$ROOT_DIR"
exec "$PYTHON" "$SCRIPT_PATH" "$@"
