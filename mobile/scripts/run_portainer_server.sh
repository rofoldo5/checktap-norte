#!/usr/bin/env bash
set -euo pipefail

API_BASE_URL="${API_BASE_URL:-http://192.168.30.51:8080}"
cd "$(dirname "$0")/.."
flutter run --dart-define="API_BASE_URL=$API_BASE_URL"
