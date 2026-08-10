#!/usr/bin/env bash
set -euo pipefail

API_BASE_URL="${API_BASE_URL:-http://192.168.30.51:8080}"
VERSION="${VERSION:-0.12.0}"
MOBILE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="$(cd "$MOBILE_DIR/.." && pwd)"
OUTPUT_DIR="$PROJECT_DIR/dist"

cd "$MOBILE_DIR"
flutter pub get
flutter analyze
flutter build apk --release --dart-define="API_BASE_URL=$API_BASE_URL"
mkdir -p "$OUTPUT_DIR"
cp build/app/outputs/flutter-apk/app-release.apk "$OUTPUT_DIR/checktap-$VERSION.apk"
sha256sum "$OUTPUT_DIR/checktap-$VERSION.apk" > "$OUTPUT_DIR/checktap-$VERSION.apk.sha256"
echo "Created $OUTPUT_DIR/checktap-$VERSION.apk"
