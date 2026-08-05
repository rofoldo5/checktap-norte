#!/usr/bin/env bash
set -euo pipefail

LOCAL_CONTAINER="${LOCAL_CONTAINER:-checktap-postgres-local}"
LOCAL_DB="${LOCAL_DB:-checktap}"
LOCAL_USER="${LOCAL_USER:-checktap}"
OUTPUT="${1:-checktap_local_$(date +%Y%m%d_%H%M%S).dump}"

docker exec "$LOCAL_CONTAINER" \
  pg_dump \
    --username "$LOCAL_USER" \
    --dbname "$LOCAL_DB" \
    --format custom \
    --no-owner \
    --no-privileges \
  > "$OUTPUT"

sha256sum "$OUTPUT" > "$OUTPUT.sha256"
echo "Local database exported: $OUTPUT"
