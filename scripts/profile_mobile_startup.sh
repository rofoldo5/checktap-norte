#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
MOBILE_DIR="$ROOT_DIR/mobile"
API_BASE_URL="${API_BASE_URL:-http://192.168.30.51:8082}"
OUTPUT_DIR="$ROOT_DIR/validation_reports/mobile_profile_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTPUT_DIR"

cd "$MOBILE_DIR"

flutter run --profile \
  --trace-startup \
  --dart-define="API_BASE_URL=$API_BASE_URL" \
  2>&1 | tee "$OUTPUT_DIR/startup_profile.log"

cat <<TXT
El archivo de traza de arranque se genera en build/start_up_info.json cuando
la ejecución termina. Copiarlo al directorio:
  $OUTPUT_DIR
Objetivos:
  - firstFrameRasterizedTimeMillis < 2000 ms
  - frame_build_time_millis p95 < 16.67 ms
  - frame_rasterizer_time_millis p95 < 16.67 ms
TXT
