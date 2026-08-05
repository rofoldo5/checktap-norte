#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(dirname "$SCRIPT_DIR")

cd "$PROJECT_DIR/deploy"

if [ ! -f .env ]; then
  cp .env.example .env
  echo "Se creo deploy/.env. Cambie las contrasenas antes de produccion."
fi

docker compose --env-file .env up -d --build
docker compose ps
