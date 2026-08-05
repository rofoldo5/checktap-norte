#!/bin/sh
set -eu
PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
MOBILE_DIR="$PROJECT_DIR/mobile"

echo "== CHECKTAP OFFLINE 2: ESCRITURA LOCAL Y COLA =="
for file in \
  "$MOBILE_DIR/lib/data/local/local_database.dart" \
  "$MOBILE_DIR/lib/data/local/sync_queue_store.dart" \
  "$MOBILE_DIR/lib/models/sync_operation.dart" \
  "$MOBILE_DIR/lib/data/repositories/task_repository.dart"; do
  [ -f "$file" ] || { echo "FALTA: $file"; exit 1; }
done

grep -q "CREATE TABLE sync_queue" "$MOBILE_DIR/lib/data/local/local_database.dart"
grep -q "CREATE_TASK" "$MOBILE_DIR/lib/data/repositories/task_repository.dart"
grep -q "COMPLETE_TASK" "$MOBILE_DIR/lib/data/repositories/task_repository.dart"
grep -q "LocalSyncState.pending" "$MOBILE_DIR/lib/data/repositories/task_repository.dart"

if command -v flutter >/dev/null 2>&1; then
  cd "$MOBILE_DIR"
  flutter pub get
  dart format lib
  dart format --output=none --set-exit-if-changed lib
  flutter analyze
else
  echo "AVISO: Flutter no esta en PATH; se omitio flutter analyze."
fi

echo "RESULTADO: OFFLINE 2 APROBADO ESTRUCTURALMENTE"
