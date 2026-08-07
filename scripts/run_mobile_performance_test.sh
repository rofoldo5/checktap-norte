#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
MOBILE_DIR="$ROOT_DIR/mobile"
OUTPUT_DIR="$ROOT_DIR/validation_reports/mobile_performance_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTPUT_DIR"

cd "$MOBILE_DIR"

flutter pub get
flutter drive --profile \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/ui_performance_test.dart \
  2>&1 | tee "$OUTPUT_DIR/ui_performance.log"

find build -type f \( -name '*timeline*' -o -name '*performance*' \) \
  -exec cp -a {} "$OUTPUT_DIR/" \; 2>/dev/null || true

printf '%s\n' "Resultados: $OUTPUT_DIR"
