#!/bin/sh
set -eu
PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
MOBILE_DIR="$PROJECT_DIR/mobile"
BACKEND_DIR="$PROJECT_DIR/backend"

echo "== CHECKTAP OFFLINE 3: SINCRONIZACION AUTOMATICA =="
grep -q "class SyncService" "$MOBILE_DIR/lib/services/sync_service.dart"
grep -q "onConnectivityChanged" "$MOBILE_DIR/lib/services/sync_trigger_service.dart"
grep -q "synchronizePending" "$MOBILE_DIR/lib/data/repositories/task_repository.dart"
grep -q 'prefix="/sync"' "$BACKEND_DIR/app/api/sync.py"

PYTHON=python3
[ -x "$BACKEND_DIR/.venv/bin/python" ] && PYTHON="$BACKEND_DIR/.venv/bin/python"
cd "$BACKEND_DIR"
"$PYTHON" -m compileall -q app tests
"$PYTHON" -m pytest -q

if command -v flutter >/dev/null 2>&1; then
  cd "$MOBILE_DIR"
  flutter analyze
fi

echo "RESULTADO: OFFLINE 3 APROBADO"
