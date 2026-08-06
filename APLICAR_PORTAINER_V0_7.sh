#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 PROJECT_DIR" >&2
  exit 1
fi

PROJECT_DIR="$(realpath "$1")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOAD_DIR="$SCRIPT_DIR/payload"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="$PROJECT_DIR/backups/portainer_v07_$STAMP"

if [[ ! -d "$PROJECT_DIR/backend" || ! -d "$PROJECT_DIR/mobile" ]]; then
  echo "ERROR: Invalid CheckTap project directory: $PROJECT_DIR" >&2
  exit 1
fi

mkdir -p "$BACKUP_DIR"
for path in \
  backend/Dockerfile \
  backend/entrypoint.sh \
  backend/.dockerignore \
  backend/app/core/config.py \
  backend/app/main.py \
  backend/app/api/health.py \
  PORTAINER_V0_7.md \
  .gitignore; do
  if [[ -e "$PROJECT_DIR/$path" ]]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$path")"
    cp -a "$PROJECT_DIR/$path" "$BACKUP_DIR/$path"
  fi
done

if [[ -d "$PROJECT_DIR/deploy/portainer" ]]; then
  mkdir -p "$BACKUP_DIR/deploy"
  cp -a "$PROJECT_DIR/deploy/portainer" "$BACKUP_DIR/deploy/portainer"
fi
if [[ -d "$PROJECT_DIR/mobile/scripts" ]]; then
  mkdir -p "$BACKUP_DIR/mobile"
  cp -a "$PROJECT_DIR/mobile/scripts" "$BACKUP_DIR/mobile/scripts"
fi

cp -a "$PAYLOAD_DIR/." "$PROJECT_DIR/"
chmod +x "$PROJECT_DIR/backend/entrypoint.sh"
find "$PROJECT_DIR/deploy/portainer" "$PROJECT_DIR/mobile/scripts" \
  -type f -name '*.sh' -exec chmod +x {} +

cd "$PROJECT_DIR/backend"
PYTHON_BIN=python3
if [[ -x .venv/bin/python ]]; then
  PYTHON_BIN=.venv/bin/python
fi
"$PYTHON_BIN" -m compileall -q app alembic tests
if "$PYTHON_BIN" -c 'import pytest' >/dev/null 2>&1; then
  PYTHONPATH=. "$PYTHON_BIN" -m pytest -q
else
  echo "INFO: pytest is not installed; backend tests skipped"
fi

"$PROJECT_DIR/deploy/portainer/00_VERIFICAR_ESTRUCTURA.sh"

echo "CheckTap Portainer v0.7 applied."
echo "Backup: $BACKUP_DIR"
echo "Next: read deploy/portainer/README_PORTAINER.md"
