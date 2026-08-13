#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_FILE="${1:-$SCRIPT_DIR/.env.portainer}"

random_hex() {
  local bytes="$1"
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex "$bytes"
  elif command -v python3 >/dev/null 2>&1; then
    python3 - "$bytes" <<'PY'
import secrets
import sys
print(secrets.token_hex(int(sys.argv[1])))
PY
  else
    echo "ERROR: openssl or python3 is required" >&2
    exit 1
  fi
}

if [[ -e "$OUTPUT_FILE" ]]; then
  echo "ERROR: $OUTPUT_FILE already exists. Move or remove it first." >&2
  exit 1
fi

POSTGRES_PASSWORD="$(random_hex 24)"
JWT_SECRET="$(random_hex 48)"
BOOTSTRAP_ADMIN_PASSWORD="Ct-$(random_hex 12)"

cat > "$OUTPUT_FILE" <<ENV
SERVER_IP=192.168.30.51
API_BIND_ADDRESS=0.0.0.0
API_PORT=8080
API_BASE_URL=http://192.168.30.51:8080
CHECKTAP_IMAGE=checktap-backend
CHECKTAP_IMAGE_TAG=0.14.1
POSTGRES_DB=checktap
POSTGRES_USER=checktap
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
JWT_SECRET=$JWT_SECRET
ACCESS_TOKEN_MINUTES=480
BOOTSTRAP_ADMIN_NAME=Administrador
BOOTSTRAP_ADMIN_EMAIL=admin@checktap.com
BOOTSTRAP_ADMIN_PASSWORD=$BOOTSTRAP_ADMIN_PASSWORD
DEFAULT_DEPARTMENT_NAME=Programacion
SELF_REGISTRATION_ENABLED=true
CORS_ORIGINS=*
REPORT_TIMEZONE=America/Montreal
ENV

chmod 600 "$OUTPUT_FILE"

echo "Variables created: $OUTPUT_FILE"
echo "API URL: http://192.168.30.51:8080"
echo "Admin email: admin@checktap.com"
echo "Admin password: $BOOTSTRAP_ADMIN_PASSWORD"
echo "Store this password in a secure place."
