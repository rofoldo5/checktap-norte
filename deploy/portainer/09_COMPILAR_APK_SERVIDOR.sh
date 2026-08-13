#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
API_BASE_URL="${API_BASE_URL:-http://192.168.30.51:8080}"
VERSION="${VERSION:-0.14.0}"
OUTPUT_DIR="$PROJECT_DIR/dist"

command -v flutter >/dev/null 2>&1 || {
  echo "ERROR: flutter is not installed" >&2
  exit 1
}

mkdir -p "$OUTPUT_DIR"
cd "$PROJECT_DIR/mobile"
flutter pub get
flutter analyze
flutter build apk --release --dart-define="API_BASE_URL=$API_BASE_URL"

SOURCE_APK="build/app/outputs/flutter-apk/app-release.apk"
OUTPUT_APK="$OUTPUT_DIR/checktap-${VERSION}.apk"
cp "$SOURCE_APK" "$OUTPUT_APK"
sha256sum "$OUTPUT_APK" > "$OUTPUT_APK.sha256"

echo "APK created: $OUTPUT_APK"
echo "API URL embedded: $API_BASE_URL"
