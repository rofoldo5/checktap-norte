#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Uso: ./APLICAR_HOTFIX.sh /ruta/al/proyecto/flutter"
  exit 1
fi

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TARGET_DIR="$(CDPATH= cd -- "$1" && pwd)"

if [ "$SCRIPT_DIR" = "$TARGET_DIR" ]; then
  echo "Error: el parche debe ejecutarse desde una carpeta externa al proyecto."
  exit 1
fi

if [ ! -f "$TARGET_DIR/pubspec.yaml" ]; then
  echo "Error: la ruta de destino no parece ser un proyecto Flutter."
  exit 1
fi

STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="$TARGET_DIR/.backups/checktap_launcher_icon_expanded_v0.11.1_$STAMP"
mkdir -p "$BACKUP_DIR"

while IFS= read -r REL_PATH; do
  [ -z "$REL_PATH" ] && continue
  SOURCE="$SCRIPT_DIR/$REL_PATH"
  DEST="$TARGET_DIR/$REL_PATH"

  if [ ! -f "$SOURCE" ]; then
    echo "Error: falta el archivo del parche: $REL_PATH"
    exit 1
  fi

  mkdir -p "$(dirname -- "$DEST")"
  if [ -f "$DEST" ]; then
    mkdir -p "$BACKUP_DIR/$(dirname -- "$REL_PATH")"
    cp -a "$DEST" "$BACKUP_DIR/$REL_PATH"
  fi
  cp -a "$SOURCE" "$DEST"
done < "$SCRIPT_DIR/MANIFIESTO_ARCHIVOS.txt"

echo "Hotfix aplicado correctamente."
echo "Respaldo: $BACKUP_DIR"
echo "Ejecuta: dart format . && flutter analyze && flutter test"
