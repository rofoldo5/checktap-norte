#!/usr/bin/env bash
set -eu

PROJECT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BACKEND_DIR="$PROJECT_DIR/backend"
MOBILE_DIR="$PROJECT_DIR/mobile"

echo "== CHECKTAP V0.6: ADMINISTRACION DE USUARIOS =="

grep -q '"/manage"' "$BACKEND_DIR/app/api/users.py"
grep -q "class UserUpdate" "$BACKEND_DIR/app/schemas/user.py"
grep -q "class UserManagementScreen" "$MOBILE_DIR/lib/screens/user_management_screen.dart"

cd "$BACKEND_DIR"
if [ -f .venv/bin/activate ]; then
  . .venv/bin/activate
fi
PYTHONPATH=. pytest -q tests/test_api.py -k validation_permissions_and_user_management

echo "RESULTADO: ESTABILIZACION 3 APROBADA"
