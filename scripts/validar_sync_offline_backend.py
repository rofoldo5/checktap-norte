#!/usr/bin/env python3
"""Validacion en vivo de idempotencia, versiones y conflictos offline."""

from __future__ import annotations

import argparse
import sys
from datetime import UTC, datetime
from uuid import uuid4

import httpx


def step(number: int, title: str) -> None:
    print(f"[{number:02d}] {title}")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)
    print(f"     OK  {message}")


def login(client: httpx.Client, base_url: str, email: str, password: str) -> str:
    response = client.post(
        f"{base_url}/api/v1/auth/login",
        json={"email": email, "password": password},
    )
    require(response.status_code == 200, f"Login HTTP {response.status_code}")
    return response.json()["access_token"]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", default="http://127.0.0.1:8000")
    parser.add_argument("--admin-email", default="admin@checktap.com")
    parser.add_argument("--admin-password", default="Admin123!")
    args = parser.parse_args()

    base_url = args.base_url.rstrip("/")
    with httpx.Client(timeout=20.0) as client:
        step(1, "Comprobar backend")
        health = client.get(f"{base_url}/health")
        require(health.status_code == 200, "Health disponible")

        step(2, "Autenticar administrador")
        token = login(
            client,
            base_url,
            args.admin_email,
            args.admin_password,
        )
        headers = {"Authorization": f"Bearer {token}"}

        task_id = str(uuid4())
        create_operation = str(uuid4())
        timestamp = datetime.now(UTC).strftime("%Y%m%d%H%M%S")

        step(3, "Crear tarea mediante cola offline")
        create_payload = {
            "operations": [
                {
                    "operation_id": create_operation,
                    "operation_type": "CREATE_TASK",
                    "entity_id": task_id,
                    "base_version": 0,
                    "payload": {
                        "title": f"Validacion offline {timestamp}",
                        "description": "Creada por el verificador Offline 2-5",
                        "priority": "ALTA",
                        "assigned_to_id": None,
                    },
                }
            ]
        }
        created = client.post(
            f"{base_url}/api/v1/sync/operations",
            headers=headers,
            json=create_payload,
        )
        require(created.status_code == 200, "Endpoint de sincronizacion responde")
        created_result = created.json()["results"][0]
        require(created_result["status"] == "APPLIED", "CREATE_TASK aplicada")
        require(created_result["task"]["version"] == 1, "Version inicial = 1")

        step(4, "Repetir la misma operacion")
        duplicate = client.post(
            f"{base_url}/api/v1/sync/operations",
            headers=headers,
            json=create_payload,
        )
        require(duplicate.status_code == 200, "Reintento responde")
        require(
            duplicate.json()["results"][0] == created_result,
            "Idempotencia confirmada sin duplicar la tarea",
        )

        step(5, "Iniciar tarea con version correcta")
        started = client.post(
            f"{base_url}/api/v1/sync/operations",
            headers=headers,
            json={
                "operations": [
                    {
                        "operation_id": str(uuid4()),
                        "operation_type": "START_TASK",
                        "entity_id": task_id,
                        "base_version": 1,
                        "payload": {},
                    }
                ]
            },
        )
        start_result = started.json()["results"][0]
        require(start_result["status"] == "APPLIED", "START_TASK aplicada")
        require(start_result["task"]["version"] == 2, "Version incrementada a 2")

        step(6, "Provocar conflicto con una version obsoleta")
        conflict = client.post(
            f"{base_url}/api/v1/sync/operations",
            headers=headers,
            json={
                "operations": [
                    {
                        "operation_id": str(uuid4()),
                        "operation_type": "COMPLETE_TASK",
                        "entity_id": task_id,
                        "base_version": 1,
                        "payload": {},
                    }
                ]
            },
        )
        conflict_result = conflict.json()["results"][0]
        require(conflict_result["status"] == "CONFLICT", "Conflicto detectado")
        require(
            conflict_result["task"]["version"] == 2,
            "Servidor devuelve la version vigente",
        )

        step(7, "Completar con la version vigente")
        completed = client.post(
            f"{base_url}/api/v1/sync/operations",
            headers=headers,
            json={
                "operations": [
                    {
                        "operation_id": str(uuid4()),
                        "operation_type": "COMPLETE_TASK",
                        "entity_id": task_id,
                        "base_version": 2,
                        "payload": {},
                    }
                ]
            },
        )
        complete_result = completed.json()["results"][0]
        require(complete_result["status"] == "APPLIED", "COMPLETE_TASK aplicada")
        require(
            complete_result["task"]["status"] == "COMPLETADA",
            "Estado final COMPLETADA",
        )
        require(complete_result["task"]["version"] == 3, "Version final = 3")
        require(
            complete_result["task"]["completed_by"]["email"]
            == args.admin_email,
            "Usuario que completo registrado",
        )

        step(8, "Comprobar lista compartida")
        tasks = client.get(f"{base_url}/api/v1/tasks", headers=headers)
        require(tasks.status_code == 200, "Listado de tareas disponible")
        matches = [item for item in tasks.json() if item["id"] == task_id]
        require(len(matches) == 1, "Existe una sola tarea con el UUID del cliente")

    print("\nRESULTADO: OFFLINE 3 Y 4 APROBADOS EN BACKEND")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"\nRESULTADO: REPROBADO\nERROR: {error}", file=sys.stderr)
        raise SystemExit(1)
