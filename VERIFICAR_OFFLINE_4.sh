#!/bin/sh
set -eu
PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
BACKEND_DIR="$PROJECT_DIR/backend"
TMP_DB="/tmp/checktap_offline4_$$.db"
TMP_LOG="/tmp/checktap_offline4_$$.log"
PORT=18041
SERVER_PID=""

cleanup() {
  if [ -n "$SERVER_PID" ]; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    wait "$SERVER_PID" >/dev/null 2>&1 || true
  fi
  rm -f "$TMP_DB" "$TMP_LOG"
}
trap cleanup EXIT INT TERM

echo "== CHECKTAP OFFLINE 4: IDEMPOTENCIA Y CONFLICTOS =="
grep -q "version" "$BACKEND_DIR/app/models/task.py"
grep -q "class ProcessedOperation" "$BACKEND_DIR/app/models/processed_operation.py"
grep -q "CONFLICT" "$BACKEND_DIR/app/api/sync.py"
test -f "$BACKEND_DIR/alembic/versions/0002_offline_sync.py"

PYTHON=python3
[ -x "$BACKEND_DIR/.venv/bin/python" ] && PYTHON="$BACKEND_DIR/.venv/bin/python"

cd "$BACKEND_DIR"
"$PYTHON" -m pytest -q

DATABASE_URL="sqlite+pysqlite:////tmp/checktap_offline4_$$.db" \
JWT_SECRET="checktap-offline4-validation-secret-123456789" \
BOOTSTRAP_ADMIN_EMAIL="admin@checktap.com" \
BOOTSTRAP_ADMIN_PASSWORD="Admin123!" \
"$PYTHON" -m alembic upgrade head

DATABASE_URL="sqlite+pysqlite:////tmp/checktap_offline4_$$.db" \
JWT_SECRET="checktap-offline4-validation-secret-123456789" \
BOOTSTRAP_ADMIN_EMAIL="admin@checktap.com" \
BOOTSTRAP_ADMIN_PASSWORD="Admin123!" \
"$PYTHON" -m uvicorn app.main:app --host 127.0.0.1 --port "$PORT" \
  >"$TMP_LOG" 2>&1 &
SERVER_PID=$!

attempt=0
until curl -fsS "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 30 ]; then
    echo "ERROR: FastAPI temporal no inicio."
    cat "$TMP_LOG"
    exit 1
  fi
  sleep 1
done

cd "$PROJECT_DIR"
"$PYTHON" scripts/validar_sync_offline_backend.py \
  --base-url "http://127.0.0.1:$PORT"

echo "RESULTADO: OFFLINE 4 APROBADO"
