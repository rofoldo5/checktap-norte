#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "ERROR: Missing $path" >&2
    exit 1
  fi
  echo "OK: $path"
}

require_file "$PROJECT_DIR/backend/Dockerfile"
require_file "$PROJECT_DIR/backend/entrypoint.sh"
require_file "$SCRIPT_DIR/compose.portainer.yaml"
require_file "$SCRIPT_DIR/.env.portainer.example"
require_file "$SCRIPT_DIR/README_PORTAINER.md"

bash -n "$PROJECT_DIR/backend/entrypoint.sh"
find "$SCRIPT_DIR" -maxdepth 1 -type f -name '*.sh' -print0 \
  | xargs -0 -n1 bash -n

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  TMP_ENV="$(mktemp)"
  trap 'rm -f "$TMP_ENV"' EXIT
  cp "$SCRIPT_DIR/.env.portainer.example" "$TMP_ENV"
  sed -i 's/CHANGE_ME_WITH_A_LONG_RANDOM_VALUE/ExampleDbPassword1234567890/' "$TMP_ENV"
  sed -i 's/CHANGE_ME_WITH_AT_LEAST_64_RANDOM_CHARACTERS/ExampleJwtSecret1234567890ExampleJwtSecret1234567890ExampleJwtSecret1234/' "$TMP_ENV"
  sed -i 's/CHANGE_ME_WITH_A_STRONG_PASSWORD/ExampleAdminPassword123!/' "$TMP_ENV"
  docker compose \
    --env-file "$TMP_ENV" \
    --file "$SCRIPT_DIR/compose.portainer.yaml" \
    config >/dev/null
  echo "OK: Docker Compose configuration"
else
  echo "INFO: Docker Compose not available; YAML runtime validation skipped"
fi

echo "RESULT: CHECKTAP PORTAINER STRUCTURE APPROVED"
