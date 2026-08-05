#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(dirname "$SCRIPT_DIR")
MOBILE_DIR="$PROJECT_DIR/mobile"

if [ -d "$MOBILE_DIR/android" ] && [ -d "$MOBILE_DIR/ios" ]; then
  echo "Android e iOS ya existen. No se regeneran para proteger la configuracion offline."
  echo "Use flutter pub get dentro de mobile."
  exit 0
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter no esta instalado o no esta en PATH."
  exit 1
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

flutter create \
  --platforms=android,ios \
  --org=com.sistemasnorte \
  --project-name=checktap \
  "$TMP_DIR/checktap"

[ -d "$MOBILE_DIR/android" ] || cp -R "$TMP_DIR/checktap/android" "$MOBILE_DIR/android"
[ -d "$MOBILE_DIR/ios" ] || cp -R "$TMP_DIR/checktap/ios" "$MOBILE_DIR/ios"

cd "$MOBILE_DIR"
flutter pub get

echo "Plataformas Flutter preparadas. Aplique despues la configuracion offline del proyecto."
