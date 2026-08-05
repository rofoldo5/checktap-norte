#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${1:-$SCRIPT_DIR/.env.portainer}"
BACKUP_DIR="${2:-$SCRIPT_DIR/backups}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: Missing $ENV_FILE" >&2
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

mkdir -p "$BACKUP_DIR"
STAMP="$(date +%Y%m%d_%H%M%S)"
OUTPUT="$BACKUP_DIR/checktap_${STAMP}.dump"

docker exec \
  -e PGPASSWORD="$POSTGRES_PASSWORD" \
  checktap-postgres \
  pg_dump \
    --username "$POSTGRES_USER" \
    --dbname "$POSTGRES_DB" \
    --format custom \
    --no-owner \
    --no-privileges \
  > "$OUTPUT"

sha256sum "$OUTPUT" > "$OUTPUT.sha256"

echo "Backup created: $OUTPUT"
echo "Checksum: $OUTPUT.sha256"
