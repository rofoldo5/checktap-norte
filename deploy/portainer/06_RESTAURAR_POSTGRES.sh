#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 BACKUP.dump [ENV_FILE]" >&2
  exit 1
fi

BACKUP_FILE="$(realpath "$1")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${2:-$SCRIPT_DIR/.env.portainer}"

if [[ ! -f "$BACKUP_FILE" ]]; then
  echo "ERROR: Backup not found: $BACKUP_FILE" >&2
  exit 1
fi
if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: Missing $ENV_FILE" >&2
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

read -r -p "This will replace data in $POSTGRES_DB. Type RESTORE: " CONFIRM
if [[ "$CONFIRM" != "RESTORE" ]]; then
  echo "Restore cancelled."
  exit 1
fi

docker stop checktap-api >/dev/null 2>&1 || true

docker exec \
  -e PGPASSWORD="$POSTGRES_PASSWORD" \
  checktap-postgres \
  psql \
    --username "$POSTGRES_USER" \
    --dbname postgres \
    --command "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$POSTGRES_DB' AND pid <> pg_backend_pid();" \
    >/dev/null

docker exec \
  -e PGPASSWORD="$POSTGRES_PASSWORD" \
  checktap-postgres \
  dropdb --if-exists --username "$POSTGRES_USER" "$POSTGRES_DB"

docker exec \
  -e PGPASSWORD="$POSTGRES_PASSWORD" \
  checktap-postgres \
  createdb --username "$POSTGRES_USER" "$POSTGRES_DB"

cat "$BACKUP_FILE" | docker exec -i \
  -e PGPASSWORD="$POSTGRES_PASSWORD" \
  checktap-postgres \
  pg_restore \
    --username "$POSTGRES_USER" \
    --dbname "$POSTGRES_DB" \
    --no-owner \
    --no-privileges

docker start checktap-api >/dev/null

echo "Restore completed."
