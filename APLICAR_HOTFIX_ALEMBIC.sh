#!/bin/sh
set -eu

PATCH_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TARGET_ROOT=${1:-}

if [ -z "$TARGET_ROOT" ]; then
  if [ -d "./backend/alembic/versions" ]; then
    TARGET_ROOT=$(pwd)
  else
    echo "Uso: sh APLICAR_HOTFIX_ALEMBIC.sh /ruta/a/checktap/system" >&2
    exit 2
  fi
fi

TARGET_ROOT=$(CDPATH= cd -- "$TARGET_ROOT" && pwd)
if [ ! -d "$TARGET_ROOT/backend/alembic/versions" ] || [ ! -f "$TARGET_ROOT/backend/alembic/versions/0006_user_self_registration.py" ]; then
  echo "ERROR: el destino no contiene el historial Alembic esperado de CheckTap." >&2
  exit 3
fi

STAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_ROOT="$TARGET_ROOT/.checktap_backups/alembic_recurrencia_0007_$STAMP"
mkdir -p "$BACKUP_ROOT"

backup_file() {
  rel=$1
  dest="$TARGET_ROOT/$rel"
  if [ -f "$dest" ]; then
    mkdir -p "$BACKUP_ROOT/$(dirname "$rel")"
    cp -p "$dest" "$BACKUP_ROOT/$rel"
  fi
}

while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  src="$PATCH_DIR/$rel"
  dest="$TARGET_ROOT/$rel"
  if [ ! -f "$src" ]; then
    echo "ERROR: falta archivo del hotfix: $rel" >&2
    exit 4
  fi
  backup_file "$rel"
  mkdir -p "$(dirname "$dest")"
  cp -p "$src" "$dest"
done < "$PATCH_DIR/HOTFIX_ARCHIVOS_COPIAR.txt"

while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  dest="$TARGET_ROOT/$rel"
  if [ -f "$dest" ]; then
    backup_file "$rel"
    rm -f "$dest"
  fi
done < "$PATCH_DIR/HOTFIX_ARCHIVOS_ELIMINAR.txt"

echo "Hotfix Alembic aplicado."
echo "Respaldo: $BACKUP_ROOT"

cd "$TARGET_ROOT/backend"
ALEMBIC_CMD=""
if [ -x ".venv/bin/alembic" ]; then
  ALEMBIC_CMD=".venv/bin/alembic"
elif command -v alembic >/dev/null 2>&1; then
  ALEMBIC_CMD="$(command -v alembic)"
fi

if [ -n "$ALEMBIC_CMD" ]; then
  echo
  echo "Heads detectados despues del hotfix:"
  "$ALEMBIC_CMD" heads
else
  echo
  echo "Alembic no esta disponible en el entorno actual; omito la comprobacion automatica."
fi

echo
echo "NO se ejecuto la migracion sobre la base de datos automaticamente."
echo "Despues de hacer respaldo, ejecute desde backend/:"
echo "  alembic current"
echo "  alembic upgrade head"
echo "  alembic current"
echo "Resultado esperado: 0007_task_recurrence (head)"
