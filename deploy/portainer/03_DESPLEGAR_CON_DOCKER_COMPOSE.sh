#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${1:-$SCRIPT_DIR/.env.portainer}"
COMPOSE_FILE="$SCRIPT_DIR/compose.portainer.yaml"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: Missing $ENV_FILE" >&2
  exit 1
fi

command -v docker >/dev/null 2>&1 || {
  echo "ERROR: docker is not installed" >&2
  exit 1
}

docker volume inspect checktap_postgres_data >/dev/null 2>&1 \
  || docker volume create checktap_postgres_data >/dev/null

docker compose \
  --project-name checktap \
  --env-file "$ENV_FILE" \
  --file "$COMPOSE_FILE" \
  up -d

echo "CheckTap deployed with Docker Compose."
