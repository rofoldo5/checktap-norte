#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${1:-$SCRIPT_DIR/.env.portainer}"

"$SCRIPT_DIR/00_VERIFICAR_ESTRUCTURA.sh"

if [[ -f "$ENV_FILE" ]] && command -v docker >/dev/null 2>&1; then
  "$SCRIPT_DIR/04_VERIFICAR_DESPLIEGUE.sh" "$ENV_FILE"
else
  echo "INFO: Runtime deployment validation skipped."
  echo "Create .env.portainer and deploy the stack to enable it."
fi
