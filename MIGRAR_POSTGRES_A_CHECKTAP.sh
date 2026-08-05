#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"
cd "$ROOT"

if [ ! -f "deploy/compose.local.yaml" ]; then
  echo "ERROR: Ejecuta este script desde la raiz del proyecto."
  exit 1
fi
if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: Docker no esta instalado o no esta disponible en PATH."
  exit 1
fi

OLD_CONTAINER="taskflow-postgres-local"
NEW_CONTAINER="checktap-postgres-local"
BACKUP_DIR="backups/postgres_checktap_$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/taskflow_before_checktap.sql"
mkdir -p "$BACKUP_DIR"

container_exists() {
  docker ps -a --format '{{.Names}}' | grep -Fxq "$1"
}
container_running() {
  docker ps --format '{{.Names}}' | grep -Fxq "$1"
}

if container_exists "$OLD_CONTAINER"; then
  echo "Se encontro la base anterior: $OLD_CONTAINER"
  if ! container_running "$OLD_CONTAINER"; then
    docker start "$OLD_CONTAINER" >/dev/null
  fi

  echo "Esperando PostgreSQL anterior..."
  for _ in $(seq 1 60); do
    if docker exec "$OLD_CONTAINER" pg_isready -U taskflow -d taskflow >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
  docker exec "$OLD_CONTAINER" pg_isready -U taskflow -d taskflow >/dev/null

  echo "Generando respaldo SQL en $BACKUP_FILE ..."
  docker exec "$OLD_CONTAINER" \
    pg_dump -U taskflow -d taskflow --no-owner --no-acl \
    > "$BACKUP_FILE"

  if [ ! -s "$BACKUP_FILE" ]; then
    echo "ERROR: El respaldo quedo vacio. No se modifico el contenedor anterior."
    exit 1
  fi

  echo "Deteniendo el contenedor anterior sin eliminar su volumen..."
  docker rm -f "$OLD_CONTAINER" >/dev/null
else
  echo "No se encontro $OLD_CONTAINER. Se creara una base CheckTap nueva."
fi

if container_exists "$NEW_CONTAINER"; then
  docker rm -f "$NEW_CONTAINER" >/dev/null
fi

echo "Levantando PostgreSQL CheckTap..."
docker compose -f deploy/compose.local.yaml up -d postgres

for _ in $(seq 1 60); do
  if docker exec "$NEW_CONTAINER" pg_isready -U checktap -d checktap >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
docker exec "$NEW_CONTAINER" pg_isready -U checktap -d checktap >/dev/null

if [ -s "$BACKUP_FILE" ]; then
  echo "Restaurando datos en la base CheckTap..."
  docker exec -i "$NEW_CONTAINER" psql -v ON_ERROR_STOP=1 -U checktap -d checktap \
    < "$BACKUP_FILE"
fi

# Corregir los correos historicos sin eliminar usuarios ni relaciones.
docker exec -i "$NEW_CONTAINER" psql -v ON_ERROR_STOP=1 -U checktap -d checktap <<'SQL'
DO $$
BEGIN
  IF to_regclass('public.users') IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM users WHERE email = 'admin@taskflow.com')
       AND NOT EXISTS (SELECT 1 FROM users WHERE email = 'admin@checktap.com') THEN
      UPDATE users
      SET email = 'admin@checktap.com'
      WHERE email = 'admin@taskflow.com';
    END IF;

    IF EXISTS (SELECT 1 FROM users WHERE email = 'admin@taskflow.local')
       AND NOT EXISTS (SELECT 1 FROM users WHERE email = 'admin.legacy@checktap.com') THEN
      UPDATE users
      SET email = 'admin.legacy@checktap.com'
      WHERE email = 'admin@taskflow.local';
    END IF;
  END IF;
END $$;
SQL

cat <<MSG

Migracion completada.

Contenedor nuevo: $NEW_CONTAINER
Base de datos:    checktap
Usuario:          checktap
Respaldo:         $BACKUP_FILE

El volumen anterior no fue eliminado y queda disponible como respaldo adicional.
Ahora puedes ejecutar:

  ./scripts/run_backend_local.sh

Credenciales esperadas:
  Correo: admin@checktap.com
  Clave:  Admin123!
MSG
