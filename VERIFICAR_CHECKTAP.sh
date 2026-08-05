#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"
cd "$ROOT"

FAILED=0

check_absent() {
  local pattern="$1"
  local label="$2"
  local output
  output="$(grep -RIn \
    --exclude-dir=.git \
    --exclude-dir=.venv \
    --exclude-dir=.dart_tool \
    --exclude-dir=.gradle \
    --exclude-dir=build \
    --exclude-dir=Pods \
    --exclude-dir=backups \
    --exclude='APLICAR_CAMBIO_NOMBRE_CHECKTAP.sh' \
    --exclude='MIGRAR_POSTGRES_A_CHECKTAP.sh' \
    --exclude='VERIFICAR_CHECKTAP.sh' \
    --exclude='APLICAR.md' \
    --exclude='*.db' \
    -E "$pattern" . || true)"
  if [ -n "$output" ]; then
    echo "FALLO: Todavia hay referencias a $label:"
    echo "$output"
    FAILED=1
  else
    echo "OK: No quedan referencias a $label."
  fi
}

check_absent 'TaskFlow|Taskflow|TASKFLOW' 'TaskFlow'
check_absent 'com\.sistemasnorte\.taskflow' 'com.sistemasnorte.taskflow'

required_strings=(
  'name: checktap'
  'com.sistemasnorte.checktap'
  'CheckTap'
  'admin@checktap.com'
)
for item in "${required_strings[@]}"; do
  if grep -RIl \
      --exclude-dir=.git \
      --exclude-dir=.venv \
      --exclude-dir=.dart_tool \
      --exclude-dir=.gradle \
      --exclude-dir=build \
      --exclude-dir=Pods \
      --exclude-dir=backups \
      --exclude='APLICAR_CAMBIO_NOMBRE_CHECKTAP.sh' \
      --exclude='MIGRAR_POSTGRES_A_CHECKTAP.sh' \
      --exclude='VERIFICAR_CHECKTAP.sh' \
      --exclude='APLICAR.md' \
      -F "$item" . >/dev/null; then
    echo "OK: Encontrado '$item'."
  else
    echo "FALLO: No se encontro '$item'."
    FAILED=1
  fi
done

if command -v flutter >/dev/null 2>&1; then
  echo "Ejecutando flutter pub get y flutter analyze..."
  (
    cd mobile
    flutter pub get
    flutter analyze
  )
else
  echo "AVISO: Flutter no esta en PATH; se omitio flutter analyze."
fi

if command -v python3 >/dev/null 2>&1; then
  echo "Verificando sintaxis Python..."
  python3 -m compileall -q backend/app
fi

if [ "$FAILED" -ne 0 ]; then
  exit 1
fi

echo "Verificacion de marca CheckTap completada."
