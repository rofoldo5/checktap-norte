#!/usr/bin/env bash
set -eu

PROJECT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BACKEND_DIR="$PROJECT_DIR/backend"
MOBILE_DIR="$PROJECT_DIR/mobile"

echo "== CHECKTAP V0.6: INFORME PDF EN FLUTTER =="

grep -q "share_plus: 10.1.4" "$MOBILE_DIR/pubspec.yaml"
grep -q "class ReportScreen" "$MOBILE_DIR/lib/screens/report_screen.dart"
grep -q "downloadDailyReport" "$MOBILE_DIR/lib/services/task_service.dart"

cd "$BACKEND_DIR"
if [ -f .venv/bin/activate ]; then
  . .venv/bin/activate
fi
PYTHONPATH=. pytest -q tests/test_api.py -k daily_report

echo "RESULTADO: ESTABILIZACION 4 APROBADA"
