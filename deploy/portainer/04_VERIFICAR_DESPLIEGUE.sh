#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${1:-$SCRIPT_DIR/.env.portainer}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: Missing $ENV_FILE" >&2
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

BASE_URL="${API_BASE_URL:-http://${SERVER_IP}:${API_PORT}}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

wait_for_health() {
  local attempts=40
  local i
  for ((i = 1; i <= attempts; i++)); do
    if curl -fsS --connect-timeout 3 "$BASE_URL/health" > "$TMP_DIR/health.json"; then
      return 0
    fi
    sleep 3
  done
  return 1
}

echo "Checking $BASE_URL/health ..."
if ! wait_for_health; then
  echo "ERROR: API did not become healthy" >&2
  command -v docker >/dev/null 2>&1 && docker logs --tail 100 checktap-api || true
  exit 1
fi
cat "$TMP_DIR/health.json"
echo

LOGIN_BODY=$(printf '{"email":"%s","password":"%s"}' \
  "$BOOTSTRAP_ADMIN_EMAIL" "$BOOTSTRAP_ADMIN_PASSWORD")

HTTP_CODE=$(curl -sS \
  -o "$TMP_DIR/login.json" \
  -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "$LOGIN_BODY" \
  "$BASE_URL/api/v1/auth/login")

if [[ "$HTTP_CODE" != "200" ]]; then
  echo "ERROR: Login failed with HTTP $HTTP_CODE" >&2
  cat "$TMP_DIR/login.json" >&2
  exit 1
fi

TOKEN=$(sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p' "$TMP_DIR/login.json")
if [[ -z "$TOKEN" ]]; then
  echo "ERROR: Could not extract access token" >&2
  cat "$TMP_DIR/login.json" >&2
  exit 1
fi

for path in /api/v1/auth/me /api/v1/users /api/v1/tasks; do
  code=$(curl -sS \
    -o "$TMP_DIR/response.json" \
    -w '%{http_code}' \
    -H "Authorization: Bearer $TOKEN" \
    "$BASE_URL$path")
  if [[ "$code" != "200" ]]; then
    echo "ERROR: $path returned HTTP $code" >&2
    cat "$TMP_DIR/response.json" >&2
    exit 1
  fi
  echo "OK: $path"
done

REPORT_DATE=$(date +%F)
code=$(curl -sS \
  -o "$TMP_DIR/report.pdf" \
  -w '%{http_code}' \
  -H "Authorization: Bearer $TOKEN" \
  "$BASE_URL/api/v1/reports/daily.pdf?date=$REPORT_DATE")

if [[ "$code" != "200" ]]; then
  echo "ERROR: PDF report returned HTTP $code" >&2
  exit 1
fi

if [[ "$(head -c 4 "$TMP_DIR/report.pdf")" != "%PDF" ]]; then
  echo "ERROR: Report response is not a PDF" >&2
  exit 1
fi

echo "OK: PDF report"
echo "RESULT: CHECKTAP PORTAINER DEPLOYMENT APPROVED"
