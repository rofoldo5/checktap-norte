#!/bin/sh
set -eu

PATCH_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TARGET_ROOT=${1:-}

if [ -z "$TARGET_ROOT" ]; then
  if [ -d "./backend" ] && [ -d "./mobile" ]; then
    TARGET_ROOT=$(pwd)
  else
    echo "Uso: sh APLICAR_CAMBIO.sh /ruta/a/checktap/system" >&2
    exit 2
  fi
fi

TARGET_ROOT=$(CDPATH= cd -- "$TARGET_ROOT" && pwd)
if [ ! -d "$TARGET_ROOT/backend" ] || [ ! -d "$TARGET_ROOT/mobile" ]; then
  echo "ERROR: $TARGET_ROOT no parece ser la raiz de CheckTap (faltan backend/ o mobile/)." >&2
  exit 3
fi

STAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_ROOT="$TARGET_ROOT/.checktap_backups/tareas_recurrentes_v0.14.1_$STAMP"
mkdir -p "$BACKUP_ROOT"

backup_file() {
  rel=$1
  dest="$TARGET_ROOT/$rel"
  if [ -f "$dest" ]; then
    mkdir -p "$BACKUP_ROOT/$(dirname "$rel")"
    cp -p "$dest" "$BACKUP_ROOT/$rel"
  fi
}

count=0
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  src="$PATCH_DIR/$rel"
  dest="$TARGET_ROOT/$rel"
  if [ ! -f "$src" ]; then
    echo "ERROR: falta archivo del parche: $rel" >&2
    exit 4
  fi
  backup_file "$rel"
  mkdir -p "$(dirname "$dest")"
  cp -p "$src" "$dest"
  count=$((count + 1))
done < "$PATCH_DIR/ARCHIVOS_PARCHE.txt"

removed=0
if [ -f "$PATCH_DIR/ARCHIVOS_ELIMINAR.txt" ]; then
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    dest="$TARGET_ROOT/$rel"
    if [ -f "$dest" ]; then
      backup_file "$rel"
      rm -f "$dest"
      removed=$((removed + 1))
    fi
  done < "$PATCH_DIR/ARCHIVOS_ELIMINAR.txt"
fi

echo "Parche aplicado: $count archivos copiados; $removed archivos obsoletos eliminados."
echo "Respaldo: $BACKUP_ROOT"
echo "Version objetivo: CheckTap backend 0.14.1 / APK 0.14.1+18"
echo
echo "IMPORTANTE: esta version usa Alembic como unica fuente de migracion de esquema."
echo "El entrypoint del backend ya ejecuta 'alembic upgrade head' antes de iniciar API/scheduler."
echo
echo "Validacion recomendada antes de desplegar:"
echo "  1) cd $TARGET_ROOT/backend && alembic current"
echo "  2) cd $TARGET_ROOT/backend && alembic upgrade head"
echo "  3) cd $TARGET_ROOT/backend && PYTHONPATH=. pytest -q"
echo "  4) cd $TARGET_ROOT/mobile && flutter pub get"
echo "  5) dart format lib test"
echo "  6) flutter analyze --fatal-infos"
echo "  7) flutter test"
echo "  8) reconstruir y desplegar api + scheduler; luego generar el APK"
