#!/usr/bin/env bash
set -eu

PROJECT_DIR="${1:-$HOME/Documents/checktap/system}"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PAYLOAD_DIR="$SCRIPT_DIR/payload"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="$PROJECT_DIR/backups/estabilizacion_v06_$STAMP"

if [ ! -d "$PROJECT_DIR/backend/app" ] || [ ! -d "$PROJECT_DIR/mobile/lib" ]; then
  echo "ERROR: No se encontro un proyecto CheckTap valido en: $PROJECT_DIR" >&2
  exit 1
fi

mkdir -p "$BACKUP_DIR"

echo "== RESPALDO =="
cd "$PAYLOAD_DIR"
find . -type f | while IFS= read -r relative; do
  relative="${relative#./}"
  if [ -f "$PROJECT_DIR/$relative" ]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$relative")"
    cp -a "$PROJECT_DIR/$relative" "$BACKUP_DIR/$relative"
  fi
done

echo "Respaldo: $BACKUP_DIR"

echo "== APLICAR CHECKTAP V0.6 =="
cp -a "$PAYLOAD_DIR/." "$PROJECT_DIR/"
chmod +x "$PROJECT_DIR"/VERIFICAR_ESTABILIZACION_*.sh
chmod +x "$PROJECT_DIR/VALIDAR_ESTABILIZACION_V0_6.sh"

echo "== BACKEND =="
cd "$PROJECT_DIR/backend"
if [ -f .venv/bin/activate ]; then
  . .venv/bin/activate
fi
python -m compileall -q app tests
PYTHONPATH=. pytest -q

echo "== FLUTTER =="
if command -v flutter >/dev/null 2>&1; then
  cd "$PROJECT_DIR/mobile"
  flutter clean
  flutter pub get
  dart format lib
  flutter analyze
else
  echo "AVISO: Flutter no esta disponible en PATH. Ejecute luego flutter pub get y flutter analyze."
fi

echo "CHECKTAP V0.6 APLICADO CORRECTAMENTE"
echo "Ejecute: $PROJECT_DIR/VALIDAR_ESTABILIZACION_V0_6.sh"
