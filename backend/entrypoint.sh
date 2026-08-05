#!/bin/sh
set -eu

DB_STARTUP_MAX_ATTEMPTS="${DB_STARTUP_MAX_ATTEMPTS:-60}"
DB_STARTUP_DELAY_SECONDS="${DB_STARTUP_DELAY_SECONDS:-2}"
UVICORN_WORKERS="${UVICORN_WORKERS:-1}"

python - <<'PY'
import os
import time

from sqlalchemy import create_engine, text

url = os.environ.get("DATABASE_URL", "")
max_attempts = int(os.environ.get("DB_STARTUP_MAX_ATTEMPTS", "60"))
delay = float(os.environ.get("DB_STARTUP_DELAY_SECONDS", "2"))

if not url:
    raise SystemExit("DATABASE_URL is required")

engine = create_engine(url, pool_pre_ping=True)
last_error = None
for attempt in range(1, max_attempts + 1):
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
        print("Database connection ready", flush=True)
        break
    except Exception as exc:
        last_error = exc
        print(
            f"Waiting for database ({attempt}/{max_attempts}): {exc}",
            flush=True,
        )
        time.sleep(delay)
else:
    raise SystemExit(f"Database did not become ready: {last_error}")
PY

alembic upgrade head

exec uvicorn app.main:app \
    --host 0.0.0.0 \
    --port 8000 \
    --workers "$UVICORN_WORKERS" \
    --proxy-headers \
    --forwarded-allow-ips="${FORWARDED_ALLOW_IPS:-*}" \
    --ws-ping-interval "${WS_PING_INTERVAL:-20}" \
    --ws-ping-timeout "${WS_PING_TIMEOUT:-20}" \
    --timeout-keep-alive "${KEEP_ALIVE_TIMEOUT:-30}"
