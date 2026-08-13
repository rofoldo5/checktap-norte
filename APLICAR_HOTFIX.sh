#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Uso: ./APLICAR_HOTFIX.sh /ruta/al/proyecto/checktap"
  exit 1
fi

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TARGET_DIR="$(CDPATH= cd -- "$1" && pwd)"

if [ "$SCRIPT_DIR" = "$TARGET_DIR" ]; then
  echo "Error: el parche debe ejecutarse desde una carpeta externa al proyecto."
  exit 1
fi

if [ ! -f "$TARGET_DIR/mobile/pubspec.yaml" ] || [ ! -f "$TARGET_DIR/backend/alembic.ini" ]; then
  echo "Error: la ruta de destino no parece ser la raíz del proyecto CheckTap."
  exit 1
fi

STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="$TARGET_DIR/.backups/checktap_notificaciones_solicitudes_v0_13_$STAMP"
mkdir -p "$BACKUP_DIR"

# Validar el parche completo antes de modificar el proyecto.
while IFS= read -r REL_PATH; do
  [ -z "$REL_PATH" ] && continue
  if [ ! -f "$SCRIPT_DIR/$REL_PATH" ]; then
    echo "Error: falta el archivo del parche: $REL_PATH"
    exit 1
  fi
done < "$SCRIPT_DIR/MANIFIESTO_ARCHIVOS.txt"

while IFS= read -r REL_PATH; do
  [ -z "$REL_PATH" ] && continue
  SOURCE="$SCRIPT_DIR/$REL_PATH"
  DEST="$TARGET_DIR/$REL_PATH"

  mkdir -p "$(dirname -- "$DEST")"
  if [ -f "$DEST" ]; then
    mkdir -p "$BACKUP_DIR/$(dirname -- "$REL_PATH")"
    cp -a "$DEST" "$BACKUP_DIR/$REL_PATH"
  fi
  cp -a "$SOURCE" "$DEST"
done < "$SCRIPT_DIR/MANIFIESTO_ARCHIVOS.txt"

echo "Notificaciones de solicitudes aplicadas correctamente."
echo "Respaldo: $BACKUP_DIR"
echo
echo "No hay una migración nueva de base de datos."
echo "Siguientes pasos:"
echo "  1. cd \"$TARGET_DIR/backend\" && python -m pytest -q"
echo "  2. Reinicia o reconstruye el backend de CheckTap."
echo "  3. cd \"$TARGET_DIR/mobile\" && flutter pub get"
echo "  4. dart format lib test && flutter analyze --fatal-infos && flutter test"
echo "  5. Compila e instala el APK 0.13.0."
