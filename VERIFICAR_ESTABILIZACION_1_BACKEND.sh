#!/usr/bin/env bash
set -eu

PROJECT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BACKEND_DIR="$PROJECT_DIR/backend"

echo "== CHECKTAP V0.6: VALIDACIONES Y PERMISOS BACKEND =="
cd "$BACKEND_DIR"

if [ -f .venv/bin/activate ]; then
  . .venv/bin/activate
fi

python -m compileall -q app tests
PYTHONPATH=. pytest -q

grep -q "def require_task_edit" app/services/task_permissions.py
grep -q '"UPDATE_TASK"' app/schemas/sync.py
grep -q 'response_model=list\[UserRead\]' app/api/users.py

echo "RESULTADO: ESTABILIZACION 1 APROBADA"
