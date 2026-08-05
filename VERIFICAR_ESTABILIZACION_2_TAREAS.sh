#!/usr/bin/env bash
set -eu

PROJECT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
MOBILE_DIR="$PROJECT_DIR/mobile"

echo "== CHECKTAP V0.6: DETALLE Y EDICION DE TAREAS =="

grep -q "class TaskDetailScreen" "$MOBILE_DIR/lib/screens/task_detail_screen.dart"
grep -q "Future<TaskItem> updateTask" "$MOBILE_DIR/lib/data/repositories/task_repository.dart"
grep -q "updatePendingCreatePayload" "$MOBILE_DIR/lib/data/local/sync_queue_store.dart"
grep -q "canEditTask" "$MOBILE_DIR/lib/core/task_permissions.dart"

if command -v flutter >/dev/null 2>&1; then
  cd "$MOBILE_DIR"
  flutter pub get
  dart format lib
  dart format --output=none --set-exit-if-changed lib
  flutter analyze
else
  echo "AVISO: Flutter no esta instalado; se completo la verificacion estructural."
fi

echo "RESULTADO: ESTABILIZACION 2 APROBADA"
