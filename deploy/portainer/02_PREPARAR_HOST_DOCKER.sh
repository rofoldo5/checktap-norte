#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="${1:-$SCRIPT_DIR/.env.portainer}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: Missing $ENV_FILE" >&2
  echo "Run: $SCRIPT_DIR/01_GENERAR_VARIABLES.sh" >&2
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

command -v docker >/dev/null 2>&1 || {
  echo "ERROR: docker is not installed" >&2
  exit 1
}

docker info >/dev/null

docker volume inspect checktap_postgres_data >/dev/null 2>&1 \
  || docker volume create checktap_postgres_data >/dev/null

echo "Building ${CHECKTAP_IMAGE}:${CHECKTAP_IMAGE_TAG}..."
docker build \
  --pull \
  --tag "${CHECKTAP_IMAGE}:${CHECKTAP_IMAGE_TAG}" \
  "$PROJECT_DIR/backend"

docker image inspect "${CHECKTAP_IMAGE}:${CHECKTAP_IMAGE_TAG}" >/dev/null

echo "Docker host prepared."
echo "Image: ${CHECKTAP_IMAGE}:${CHECKTAP_IMAGE_TAG}"
echo "Volume: checktap_postgres_data"
