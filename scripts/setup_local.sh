#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(dirname "$SCRIPT_DIR")
BACKEND_DIR="$PROJECT_DIR/backend"

command -v docker >/dev/null 2>&1 || {
  echo "ERROR: Docker no esta instalado."
  exit 1
}

command -v python3 >/dev/null 2>&1 || {
  echo "ERROR: Python 3 no esta instalado."
  exit 1
}

echo "[1/5] Iniciando PostgreSQL local en el puerto 5433..."
docker compose -f "$PROJECT_DIR/deploy/compose.local.yaml" up -d

echo "[2/5] Esperando PostgreSQL..."
ATTEMPTS=0
until docker exec checktap-postgres-local pg_isready -U checktap -d checktap >/dev/null 2>&1; do
  ATTEMPTS=$((ATTEMPTS + 1))
  if [ "$ATTEMPTS" -ge 30 ]; then
    echo "ERROR: PostgreSQL no estuvo listo a tiempo."
    exit 1
  fi
  sleep 1
done

cd "$BACKEND_DIR"

if [ ! -f .env ]; then
  cp .env.local.example .env
  echo "[3/5] Se creo backend/.env con valores locales."
else
  echo "[3/5] backend/.env ya existe; no se sobrescribio."
fi

if [ ! -d .venv ]; then
  python3 -m venv .venv
fi

. .venv/bin/activate

echo "[4/5] Instalando dependencias del backend..."
python -m pip install --upgrade pip
python -m pip install -r requirements-dev.txt

echo "[5/5] Aplicando migraciones..."
python -m alembic upgrade head

echo
echo "Entorno local preparado."
echo "Ejecute: ./scripts/run_backend_local.sh"
echo "Swagger: http://localhost:8000/docs"
echo "Health:  http://localhost:8000/health"
echo "Usuario: admin@checktap.com"
echo "Clave:   Admin123!"
