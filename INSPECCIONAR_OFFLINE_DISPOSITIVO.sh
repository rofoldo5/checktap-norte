#!/bin/sh
set -eu
PACKAGE_NAME="${CHECKTAP_PACKAGE:-com.sistemasnorte.checktap}"
OUTPUT_DIR="${1:-/tmp/checktap_device_inspection}"
DB_NAME="checktap_cache.db"

command -v adb >/dev/null 2>&1 || {
  echo "ERROR: adb no esta disponible."
  exit 1
}
adb get-state >/dev/null 2>&1 || {
  echo "ERROR: no hay un dispositivo Android conectado."
  exit 1
}
command -v sqlite3 >/dev/null 2>&1 || {
  echo "ERROR: sqlite3 no esta instalado en la computadora."
  exit 1
}

mkdir -p "$OUTPUT_DIR"
DB_PATH="$OUTPUT_DIR/$DB_NAME"

REMOTE_DB=$(adb shell run-as "$PACKAGE_NAME" sh -c \
  "find databases -name '$DB_NAME' -type f 2>/dev/null | head -n 1" \
  | tr -d '\r')

if [ -z "$REMOTE_DB" ]; then
  echo "ERROR: no se encontro $DB_NAME."
  echo "Abra CheckTap en modo debug y ejecute al menos un inicio de sesion."
  exit 1
fi

adb exec-out run-as "$PACKAGE_NAME" cat "$REMOTE_DB" > "$DB_PATH"

echo "== BASE LOCAL CHECKTAP =="
echo "Archivo: $DB_PATH"
echo "Tareas por estado de sincronizacion:"
sqlite3 -header -column "$DB_PATH" \
  "SELECT sync_state, COUNT(*) AS total FROM cached_tasks GROUP BY sync_state ORDER BY sync_state;"
echo
echo "Operaciones en cola:"
sqlite3 -header -column "$DB_PATH" \
  "SELECT state, operation_type, COUNT(*) AS total FROM sync_queue GROUP BY state, operation_type ORDER BY state, operation_type;"
echo
echo "Ultimas operaciones:"
sqlite3 -header -column "$DB_PATH" \
  "SELECT id, operation_type, entity_id, base_version, state, attempts, last_error FROM sync_queue ORDER BY id DESC LIMIT 20;"
echo
echo "Metadatos:"
sqlite3 -header -column "$DB_PATH" \
  "SELECT key, value FROM cache_meta ORDER BY key;"
