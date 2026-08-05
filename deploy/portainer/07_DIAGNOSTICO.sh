#!/usr/bin/env bash
set -u

echo "== Docker containers =="
docker ps -a --filter name=checktap

echo
echo "== API health =="
curl -fsS http://192.168.30.51:8080/health || true

echo
echo "== API logs =="
docker logs --tail 120 checktap-api 2>&1 || true

echo
echo "== PostgreSQL logs =="
docker logs --tail 80 checktap-postgres 2>&1 || true

echo
echo "== Volume =="
docker volume inspect checktap_postgres_data 2>&1 || true

echo
echo "== Network =="
docker network inspect checktap_backend 2>&1 || true
