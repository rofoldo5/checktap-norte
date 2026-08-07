#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
MOBILE_DIR="$ROOT_DIR/mobile"
REPORT_DIR="$ROOT_DIR/validation_reports/mobile_ui_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$REPORT_DIR"

cd "$MOBILE_DIR"

flutter pub get 2>&1 | tee "$REPORT_DIR/01_pub_get.log"
dart format --output=none --set-exit-if-changed lib test integration_test \
  2>&1 | tee "$REPORT_DIR/02_format.log"
flutter analyze --fatal-infos 2>&1 | tee "$REPORT_DIR/03_analyze.log"
flutter test --coverage --reporter expanded \
  2>&1 | tee "$REPORT_DIR/04_tests.log"

printf '%s\n' "CheckTap Mobile QA: APROBADA" | tee "$REPORT_DIR/RESULTADO.txt"
printf '%s\n' "Reportes: $REPORT_DIR"
