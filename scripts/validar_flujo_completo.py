#!/usr/bin/env python3
"""Validacion integral del flujo colaborativo de CheckTap.

Comprueba:
- salud del backend;
- autenticacion del administrador;
- creacion y autenticacion de un usuario de prueba;
- creacion y asignacion de una tarea;
- transicion PENDIENTE -> EN_PROGRESO -> COMPLETADA;
- registro de completed_by;
- visibilidad de la misma tarea desde dos sesiones;
- rechazo de una segunda finalizacion;
- generacion del informe PDF;
- eventos WebSocket task.created, task.updated y task.completed.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import random
import string
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


class ValidationFailure(RuntimeError):
    pass


@dataclass
class ApiResponse:
    status: int
    body: Any
    headers: dict[str, str]


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def suffix() -> str:
    stamp = datetime.now().strftime("%Y%m%d%H%M%S")
    random_part = "".join(random.choices(string.ascii_lowercase + string.digits, k=4))
    return f"{stamp}{random_part}"


def print_step(number: int, label: str) -> None:
    print(f"\n[{number:02d}] {label}")


def print_ok(message: str) -> None:
    print(f"     OK  {message}")


def print_info(message: str) -> None:
    print(f"     ... {message}")


def print_warn(message: str) -> None:
    print(f"     AVISO  {message}")


def make_request(
    base_url: str,
    method: str,
    path: str,
    *,
    token: str | None = None,
    payload: dict[str, Any] | None = None,
    timeout: float = 15.0,
) -> ApiResponse:
    url = f"{base_url.rstrip('/')}{path}"
    data = None
    headers = {"Accept": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"

    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            raw = response.read()
            response_headers = {key.lower(): value for key, value in response.headers.items()}
            content_type = response_headers.get("content-type", "")
            if "application/json" in content_type and raw:
                body: Any = json.loads(raw.decode("utf-8"))
            else:
                body = raw
            return ApiResponse(response.status, body, response_headers)
    except urllib.error.HTTPError as exc:
        raw = exc.read()
        response_headers = {key.lower(): value for key, value in exc.headers.items()}
        try:
            body = json.loads(raw.decode("utf-8")) if raw else None
        except (UnicodeDecodeError, json.JSONDecodeError):
            body = raw.decode("utf-8", errors="replace")
        return ApiResponse(exc.code, body, response_headers)
    except urllib.error.URLError as exc:
        raise ValidationFailure(
            f"No fue posible conectar con {url}: {exc.reason}. "
            "Confirma que FastAPI esta activo en el puerto configurado."
        ) from exc


def expect_status(response: ApiResponse, expected: int | set[int], context: str) -> None:
    expected_set = {expected} if isinstance(expected, int) else expected
    if response.status not in expected_set:
        raise ValidationFailure(
            f"{context}: se esperaba HTTP {sorted(expected_set)}, "
            f"pero se recibio HTTP {response.status}. Respuesta: {response.body!r}"
        )


def find_task(tasks: Any, task_id: str) -> dict[str, Any]:
    if not isinstance(tasks, list):
        raise ValidationFailure(f"La API de tareas no devolvio una lista: {tasks!r}")
    for item in tasks:
        if isinstance(item, dict) and item.get("id") == task_id:
            return item
    raise ValidationFailure(f"La tarea {task_id} no aparece en la lista compartida")


def login(base_url: str, email: str, password: str) -> ApiResponse:
    return make_request(
        base_url,
        "POST",
        "/api/v1/auth/login",
        payload={"email": email, "password": password},
    )


def choose_admin(
    base_url: str,
    configured_email: str | None,
    password: str,
) -> tuple[str, str, dict[str, Any]]:
    candidates: list[str] = []
    for candidate in (
        configured_email,
        os.environ.get("ADMIN_EMAIL"),
        "admin@checktap.com",
        "admin@taskflow.com",
    ):
        if candidate and candidate not in candidates:
            candidates.append(candidate)

    errors: list[str] = []
    for email in candidates:
        response = login(base_url, email, password)
        if response.status == 200 and isinstance(response.body, dict):
            token = response.body.get("access_token")
            user = response.body.get("user")
            if isinstance(token, str) and isinstance(user, dict):
                return email, token, user
        errors.append(f"{email}: HTTP {response.status}")

    raise ValidationFailure(
        "No fue posible autenticar al administrador. Intentos: " + ", ".join(errors)
    )


def websocket_url(base_url: str, token: str) -> str:
    parsed = urllib.parse.urlsplit(base_url.rstrip("/"))
    scheme = "wss" if parsed.scheme == "https" else "ws"
    query = urllib.parse.urlencode({"token": token})
    return urllib.parse.urlunsplit(
        (scheme, parsed.netloc, "/api/v1/ws/tasks", query, "")
    )


async def receive_json(websocket: Any, timeout: float) -> dict[str, Any]:
    raw = await asyncio.wait_for(websocket.recv(), timeout=timeout)
    if isinstance(raw, bytes):
        raw = raw.decode("utf-8")
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ValidationFailure(f"WebSocket devolvio un mensaje no JSON: {raw!r}") from exc
    if not isinstance(parsed, dict):
        raise ValidationFailure(f"WebSocket devolvio una estructura inesperada: {parsed!r}")
    return parsed


async def wait_for_event(
    websocket: Any,
    event_name: str,
    task_id: str,
    timeout: float,
    events: list[dict[str, Any]],
) -> dict[str, Any]:
    deadline = asyncio.get_running_loop().time() + timeout
    while True:
        remaining = deadline - asyncio.get_running_loop().time()
        if remaining <= 0:
            raise ValidationFailure(
                f"No se recibio el evento WebSocket {event_name} para la tarea {task_id}"
            )
        message = await receive_json(websocket, remaining)
        events.append(message)
        if message.get("event") == event_name and message.get("task_id") == task_id:
            return message


async def run_validation(args: argparse.Namespace) -> dict[str, Any]:
    base_url = args.base_url.rstrip("/")
    run_id = suffix()
    test_email = args.test_email or f"validacion.{run_id}@example.com"
    test_name = args.test_name or f"Validador CheckTap {run_id[-6:]}"
    task_title = args.task_title or f"Validacion integral CheckTap {run_id}"
    task_description = (
        "Tarea creada automaticamente para validar asignacion, cambio de estado, "
        "finalizacion, sesiones compartidas y sincronizacion WebSocket."
    )

    report: dict[str, Any] = {
        "application": "CheckTap",
        "started_at": now_iso(),
        "base_url": base_url,
        "run_id": run_id,
        "result": "FAILED",
        "steps": [],
        "websocket_events": [],
        "test_user": {"name": test_name, "email": test_email},
        "task": {"title": task_title},
    }

    print("=" * 72)
    print("VALIDACION INTEGRAL LOCAL - CHECKTAP")
    print("=" * 72)
    print(f"Backend: {base_url}")
    print(f"Usuario de prueba: {test_email}")

    print_step(1, "Comprobar salud del backend y de PostgreSQL")
    health = make_request(base_url, "GET", "/health")
    expect_status(health, 200, "Health check")
    if not isinstance(health.body, dict) or health.body.get("status") != "ok":
        raise ValidationFailure(f"Health check inesperado: {health.body!r}")
    print_ok("FastAPI y la conexion de base de datos responden correctamente")
    report["steps"].append({"name": "health", "status": "PASS"})

    print_step(2, "Autenticar administrador")
    admin_email, admin_token, admin_user = choose_admin(
        base_url,
        args.admin_email,
        args.admin_password,
    )
    if not admin_user.get("is_admin"):
        raise ValidationFailure(f"El usuario {admin_email} no tiene permisos de administrador")
    print_ok(f"Administrador autenticado: {admin_email}")
    report["admin"] = {"id": admin_user.get("id"), "email": admin_email}
    report["steps"].append({"name": "admin_login", "status": "PASS"})

    print_step(3, "Crear usuario colaborador")
    create_user = make_request(
        base_url,
        "POST",
        "/api/v1/users",
        token=admin_token,
        payload={
            "name": test_name,
            "email": test_email,
            "password": args.test_password,
            "is_admin": False,
        },
    )
    expect_status(create_user, 201, "Creacion del usuario")
    if not isinstance(create_user.body, dict):
        raise ValidationFailure(f"Usuario creado con respuesta inesperada: {create_user.body!r}")
    test_user_id = create_user.body.get("id")
    if not isinstance(test_user_id, str):
        raise ValidationFailure("La respuesta de creacion no contiene un id de usuario valido")
    report["test_user"].update({"id": test_user_id})
    print_ok(f"Usuario creado: {test_name} ({test_user_id})")
    report["steps"].append({"name": "create_user", "status": "PASS"})

    print_step(4, "Autenticar al usuario creado")
    test_login = login(base_url, test_email, args.test_password)
    expect_status(test_login, 200, "Login del usuario de prueba")
    if not isinstance(test_login.body, dict) or not isinstance(
        test_login.body.get("access_token"), str
    ):
        raise ValidationFailure(f"Login del colaborador inesperado: {test_login.body!r}")
    test_token = test_login.body["access_token"]
    print_ok("Segunda sesion autenticada correctamente")
    report["steps"].append({"name": "test_user_login", "status": "PASS"})

    websocket = None
    websocket_enabled = not args.skip_websocket
    connect = None
    if websocket_enabled:
        try:
            try:
                from websockets.asyncio.client import connect as ws_connect
            except ImportError:
                from websockets import connect as ws_connect  # type: ignore
            connect = ws_connect
        except ImportError:
            websocket_enabled = False
            print_warn(
                "El paquete 'websockets' no esta instalado; se validara REST sin tiempo real."
            )

    if websocket_enabled and connect is not None:
        print_step(5, "Abrir una segunda sesion WebSocket")
        ws_url = websocket_url(base_url, test_token)
        websocket = await connect(ws_url, open_timeout=args.websocket_timeout)
        connected = await receive_json(websocket, args.websocket_timeout)
        report["websocket_events"].append(connected)
        if connected.get("event") != "connected":
            raise ValidationFailure(f"Handshake WebSocket inesperado: {connected!r}")
        print_ok("WebSocket autenticado y conectado")
        report["steps"].append({"name": "websocket_connect", "status": "PASS"})
    else:
        report["steps"].append({"name": "websocket_connect", "status": "SKIPPED"})

    try:
        print_step(6, "Crear y asignar una tarea desde la sesion administrativa")
        create_task = make_request(
            base_url,
            "POST",
            "/api/v1/tasks",
            token=admin_token,
            payload={
                "title": task_title,
                "description": task_description,
                "priority": "ALTA",
                "assigned_to_id": test_user_id,
            },
        )
        expect_status(create_task, 201, "Creacion de la tarea")
        if not isinstance(create_task.body, dict):
            raise ValidationFailure(f"Tarea creada con respuesta inesperada: {create_task.body!r}")
        task_id = create_task.body.get("id")
        if not isinstance(task_id, str):
            raise ValidationFailure("La tarea creada no contiene un id valido")
        report["task"].update({"id": task_id, "initial": create_task.body})
        if create_task.body.get("status") != "PENDIENTE":
            raise ValidationFailure("La tarea nueva no quedo en estado PENDIENTE")
        assigned = create_task.body.get("assigned_to") or {}
        if assigned.get("id") != test_user_id:
            raise ValidationFailure("La tarea no quedo asignada al usuario creado")
        print_ok(f"Tarea creada y asignada: {task_id}")
        if websocket is not None:
            await wait_for_event(
                websocket,
                "task.created",
                task_id,
                args.websocket_timeout,
                report["websocket_events"],
            )
            print_ok("Evento WebSocket task.created recibido")
        report["steps"].append({"name": "create_and_assign_task", "status": "PASS"})

        print_step(7, "Confirmar que el colaborador visualiza la tarea compartida")
        tasks_for_user = make_request(
            base_url,
            "GET",
            "/api/v1/tasks",
            token=test_token,
        )
        expect_status(tasks_for_user, 200, "Listado de tareas del colaborador")
        user_task = find_task(tasks_for_user.body, task_id)
        if user_task.get("status") != "PENDIENTE":
            raise ValidationFailure("La segunda sesion no ve la tarea como PENDIENTE")
        print_ok("La tarea aparece en la segunda sesion")
        report["steps"].append({"name": "shared_pending_visibility", "status": "PASS"})

        print_step(8, "Cambiar la tarea a EN_PROGRESO como usuario asignado")
        started = make_request(
            base_url,
            "POST",
            f"/api/v1/tasks/{task_id}/start",
            token=test_token,
        )
        expect_status(started, 200, "Inicio de la tarea")
        if not isinstance(started.body, dict) or started.body.get("status") != "EN_PROGRESO":
            raise ValidationFailure(f"Estado de inicio inesperado: {started.body!r}")
        print_ok("Tarea en estado EN_PROGRESO")
        if websocket is not None:
            await wait_for_event(
                websocket,
                "task.updated",
                task_id,
                args.websocket_timeout,
                report["websocket_events"],
            )
            print_ok("Evento WebSocket task.updated recibido")
        report["steps"].append({"name": "start_task", "status": "PASS"})

        print_step(9, "Completar la tarea como usuario asignado")
        completed = make_request(
            base_url,
            "POST",
            f"/api/v1/tasks/{task_id}/complete",
            token=test_token,
        )
        expect_status(completed, 200, "Finalizacion de la tarea")
        if not isinstance(completed.body, dict):
            raise ValidationFailure(f"Finalizacion inesperada: {completed.body!r}")
        completed_by = completed.body.get("completed_by") or {}
        if completed.body.get("status") != "COMPLETADA":
            raise ValidationFailure("La tarea no quedo en estado COMPLETADA")
        if completed_by.get("id") != test_user_id or completed_by.get("email") != test_email:
            raise ValidationFailure(
                f"completed_by no corresponde al usuario asignado: {completed_by!r}"
            )
        if not completed.body.get("completed_at"):
            raise ValidationFailure("La tarea completada no registro completed_at")
        report["task"]["completed"] = completed.body
        print_ok(f"Completada por {completed_by.get('name')} ({completed_by.get('email')})")
        if websocket is not None:
            await wait_for_event(
                websocket,
                "task.completed",
                task_id,
                args.websocket_timeout,
                report["websocket_events"],
            )
            print_ok("Evento WebSocket task.completed recibido")
        report["steps"].append({"name": "complete_task", "status": "PASS"})

        print_step(10, "Verificar consistencia desde dos sesiones")
        admin_tasks = make_request(base_url, "GET", "/api/v1/tasks", token=admin_token)
        user_tasks = make_request(base_url, "GET", "/api/v1/tasks", token=test_token)
        expect_status(admin_tasks, 200, "Listado administrativo final")
        expect_status(user_tasks, 200, "Listado colaborador final")
        admin_view = find_task(admin_tasks.body, task_id)
        user_view = find_task(user_tasks.body, task_id)
        for label, view in (("administrador", admin_view), ("colaborador", user_view)):
            if view.get("status") != "COMPLETADA":
                raise ValidationFailure(f"La vista de {label} no refleja COMPLETADA")
            view_completed_by = view.get("completed_by") or {}
            if view_completed_by.get("id") != test_user_id:
                raise ValidationFailure(
                    f"La vista de {label} no conserva completed_by correctamente"
                )
        print_ok("Ambas sesiones observan el mismo estado y completed_by")
        report["steps"].append({"name": "two_session_consistency", "status": "PASS"})

        print_step(11, "Comprobar proteccion contra doble finalizacion")
        duplicate = make_request(
            base_url,
            "POST",
            f"/api/v1/tasks/{task_id}/complete",
            token=admin_token,
        )
        expect_status(duplicate, 409, "Segunda finalizacion")
        print_ok("El backend rechazo la segunda finalizacion con HTTP 409")
        report["steps"].append({"name": "duplicate_completion_guard", "status": "PASS"})

        print_step(12, "Generar informe diario PDF")
        pdf = make_request(
            base_url,
            "GET",
            "/api/v1/reports/daily.pdf",
            token=admin_token,
            timeout=30.0,
        )
        expect_status(pdf, 200, "Informe diario PDF")
        if not isinstance(pdf.body, bytes) or not pdf.body.startswith(b"%PDF"):
            raise ValidationFailure("El endpoint del informe no devolvio un PDF valido")
        report["pdf_bytes"] = len(pdf.body)
        print_ok(f"PDF valido generado ({len(pdf.body)} bytes)")
        report["steps"].append({"name": "daily_pdf", "status": "PASS"})

        if websocket is None:
            print_warn("Tiempo real no evaluado; ejecuta nuevamente sin --skip-websocket")
        else:
            report["steps"].append({"name": "realtime_events", "status": "PASS"})

        report["result"] = "PASS"
        report["finished_at"] = now_iso()
        return report
    finally:
        if websocket is not None:
            await websocket.close()


def write_report(report: dict[str, Any], report_dir: Path) -> Path:
    report_dir.mkdir(parents=True, exist_ok=True)
    path = report_dir / f"validacion_flujo_{report['run_id']}.json"
    path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    return path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Valida automaticamente el flujo colaborativo completo de CheckTap."
    )
    parser.add_argument(
        "--base-url",
        default=os.environ.get("BASE_URL", "http://127.0.0.1:8000"),
        help="URL del backend (por defecto: http://127.0.0.1:8000)",
    )
    parser.add_argument(
        "--admin-email",
        default=None,
        help="Correo del administrador; si se omite prueba admin@checktap.com y admin@taskflow.com",
    )
    parser.add_argument(
        "--admin-password",
        default=os.environ.get("ADMIN_PASSWORD", "Admin123!"),
        help="Contrasena del administrador",
    )
    parser.add_argument(
        "--test-name",
        default=None,
        help="Nombre opcional para el usuario de prueba",
    )
    parser.add_argument(
        "--test-email",
        default=None,
        help="Correo opcional para el usuario de prueba",
    )
    parser.add_argument(
        "--test-password",
        default=os.environ.get("TEST_PASSWORD", "CheckTap123!"),
        help="Contrasena del usuario de prueba",
    )
    parser.add_argument(
        "--task-title",
        default=None,
        help="Titulo opcional para la tarea de validacion",
    )
    parser.add_argument(
        "--websocket-timeout",
        type=float,
        default=10.0,
        help="Segundos de espera por evento WebSocket",
    )
    parser.add_argument(
        "--skip-websocket",
        action="store_true",
        help="Omite la comprobacion WebSocket y valida solo REST",
    )
    parser.add_argument(
        "--report-dir",
        default="validation_reports",
        help="Directorio donde se guarda el reporte JSON",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    report: dict[str, Any] | None = None
    try:
        report = asyncio.run(run_validation(args))
        report_path = write_report(report, Path(args.report_dir))
        print("\n" + "=" * 72)
        print("RESULTADO: APROBADO")
        print(f"Reporte: {report_path.resolve()}")
        print("Nota: el usuario y la tarea de prueba permanecen en la base de datos.")
        print("=" * 72)
        return 0
    except KeyboardInterrupt:
        print("\nValidacion cancelada por el usuario.", file=sys.stderr)
        return 130
    except Exception as exc:
        failure_report = report or {
            "application": "CheckTap",
            "started_at": now_iso(),
            "base_url": args.base_url,
            "run_id": suffix(),
            "steps": [],
        }
        failure_report["result"] = "FAILED"
        failure_report["finished_at"] = now_iso()
        failure_report["error"] = str(exc)
        report_path = write_report(failure_report, Path(args.report_dir))
        print("\n" + "=" * 72, file=sys.stderr)
        print("RESULTADO: FALLIDO", file=sys.stderr)
        print(f"Causa: {exc}", file=sys.stderr)
        print(f"Reporte: {report_path.resolve()}", file=sys.stderr)
        print("=" * 72, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
