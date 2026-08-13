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
BACKUP_ROOT="$TARGET_ROOT/.checktap_backups/tareas_recurrentes_v0.14.0_$STAMP"
mkdir -p "$BACKUP_ROOT"

count=0
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  src="$PATCH_DIR/$rel"
  dest="$TARGET_ROOT/$rel"
  if [ ! -f "$src" ]; then
    echo "ERROR: falta archivo del parche: $rel" >&2
    exit 4
  fi
  if [ -f "$dest" ]; then
    mkdir -p "$BACKUP_ROOT/$(dirname "$rel")"
    cp -p "$dest" "$BACKUP_ROOT/$rel"
  fi
  mkdir -p "$(dirname "$dest")"
  cp -p "$src" "$dest"
  count=$((count + 1))
done < "$PATCH_DIR/ARCHIVOS_PARCHE.txt"

echo "Parche aplicado: $count archivos."
echo "Respaldo: $BACKUP_ROOT"
echo "Version objetivo: CheckTap backend 0.14.0 / APK 0.14.0+17"
echo
echo "Siguientes pasos recomendados:"
echo "  1) cd $TARGET_ROOT/backend && PYTHONPATH=. pytest -q"
echo "  2) cd $TARGET_ROOT/mobile && flutter pub get"
echo "  3) dart format lib test"
echo "  4) flutter analyze --fatal-infos"
echo "  5) flutter test"
echo "  6) reconstruir y desplegar api + scheduler, y luego generar el APK"
