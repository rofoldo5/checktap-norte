from fastapi.testclient import TestClient

from app.main import app


def test_health_login_and_task_flow() -> None:
    with TestClient(app) as client:
        health = client.get("/health")
        assert health.status_code == 200

        login = client.post(
            "/api/v1/auth/login",
            json={"email": "admin@example.com", "password": "Admin123!"},
        )
        assert login.status_code == 200, login.text
        token = login.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        created_user = client.post(
            "/api/v1/users",
            headers=headers,
            json={
                "name": "Operador Uno",
                "email": "operador@example.com",
                "password": "Operador123!",
                "is_admin": False,
            },
        )
        assert created_user.status_code == 201, created_user.text
        user_id = created_user.json()["id"]

        created_task = client.post(
            "/api/v1/tasks",
            headers=headers,
            json={
                "title": "Revisar inventario",
                "description": "Validar existencias del dia",
                "priority": "ALTA",
                "assigned_to_id": user_id,
            },
        )
        assert created_task.status_code == 201, created_task.text
        task_id = created_task.json()["id"]

        completed = client.post(
            f"/api/v1/tasks/{task_id}/complete",
            headers=headers,
        )
        assert completed.status_code == 200, completed.text
        assert completed.json()["status"] == "COMPLETADA"
        assert completed.json()["completed_by"]["email"] == "admin@example.com"

        duplicate_completion = client.post(
            f"/api/v1/tasks/{task_id}/complete",
            headers=headers,
        )
        assert duplicate_completion.status_code == 409


def test_daily_report_requires_authentication() -> None:
    with TestClient(app) as client:
        response = client.get("/api/v1/reports/daily.pdf")
        assert response.status_code == 401


def test_daily_report_pdf() -> None:
    with TestClient(app) as client:
        login = client.post(
            "/api/v1/auth/login",
            json={"email": "admin@example.com", "password": "Admin123!"},
        )
        token = login.json()["access_token"]
        response = client.get(
            "/api/v1/reports/daily.pdf",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 200
        assert response.headers["content-type"] == "application/pdf"
        assert response.content.startswith(b"%PDF")


def test_offline_sync_idempotency_and_conflict() -> None:
    from uuid import uuid4

    with TestClient(app) as client:
        login = client.post(
            "/api/v1/auth/login",
            json={"email": "admin@example.com", "password": "Admin123!"},
        )
        token = login.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        task_id = str(uuid4())
        create_operation_id = str(uuid4())
        create_payload = {
            "operations": [
                {
                    "operation_id": create_operation_id,
                    "operation_type": "CREATE_TASK",
                    "entity_id": task_id,
                    "base_version": 0,
                    "payload": {
                        "title": "Tarea creada sin conexion",
                        "description": "Se sincroniza al recuperar red",
                        "priority": "MEDIA",
                        "assigned_to_id": None,
                    },
                }
            ]
        }

        created = client.post(
            "/api/v1/sync/operations",
            headers=headers,
            json=create_payload,
        )
        assert created.status_code == 200, created.text
        created_result = created.json()["results"][0]
        assert created_result["status"] == "APPLIED"
        assert created_result["task"]["id"] == task_id
        assert created_result["task"]["version"] == 1

        duplicate = client.post(
            "/api/v1/sync/operations",
            headers=headers,
            json=create_payload,
        )
        assert duplicate.status_code == 200, duplicate.text
        assert duplicate.json()["results"][0] == created_result

        start = client.post(
            "/api/v1/sync/operations",
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
        assert start.status_code == 200, start.text
        assert start.json()["results"][0]["status"] == "APPLIED"
        assert start.json()["results"][0]["task"]["version"] == 2

        stale_complete = client.post(
            "/api/v1/sync/operations",
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
        assert stale_complete.status_code == 200, stale_complete.text
        stale_result = stale_complete.json()["results"][0]
        assert stale_result["status"] == "CONFLICT"
        assert stale_result["task"]["version"] == 2

        complete = client.post(
            "/api/v1/sync/operations",
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
        assert complete.status_code == 200, complete.text
        complete_result = complete.json()["results"][0]
        assert complete_result["status"] == "APPLIED"
        assert complete_result["task"]["status"] == "COMPLETADA"
        assert complete_result["task"]["version"] == 3


def _login(client: TestClient, email: str, password: str) -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": password},
    )
    assert response.status_code == 200, response.text
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def test_validation_permissions_and_user_management() -> None:
    with TestClient(app) as client:
        admin_headers = _login(client, "admin@example.com", "Admin123!")

        invalid_user = client.post(
            "/api/v1/users",
            headers=admin_headers,
            json={
                "name": "   ",
                "email": "blank@example.com",
                "password": "Secret123!",
                "is_admin": False,
            },
        )
        assert invalid_user.status_code == 422

        operator_one = client.post(
            "/api/v1/users",
            headers=admin_headers,
            json={
                "name": "Operador Dos",
                "email": "operador2@example.com",
                "password": "Operador123!",
                "is_admin": False,
            },
        )
        assert operator_one.status_code == 201, operator_one.text
        operator_one_id = operator_one.json()["id"]

        operator_two = client.post(
            "/api/v1/users",
            headers=admin_headers,
            json={
                "name": "Operador Tres",
                "email": "operador3@example.com",
                "password": "Operador123!",
                "is_admin": False,
            },
        )
        assert operator_two.status_code == 201, operator_two.text
        operator_two_id = operator_two.json()["id"]

        operator_one_headers = _login(
            client,
            "operador2@example.com",
            "Operador123!",
        )
        operator_two_headers = _login(
            client,
            "operador3@example.com",
            "Operador123!",
        )

        created_task = client.post(
            "/api/v1/tasks",
            headers=operator_one_headers,
            json={
                "title": "Tarea protegida",
                "description": "Solo creador, asignado o admin segun la accion",
                "priority": "MEDIA",
                "assigned_to_id": operator_two_id,
            },
        )
        assert created_task.status_code == 201, created_task.text
        task_id = created_task.json()["id"]

        forbidden_edit = client.patch(
            f"/api/v1/tasks/{task_id}",
            headers=operator_two_headers,
            json={"title": "Intento no autorizado"},
        )
        assert forbidden_edit.status_code == 403

        allowed_start = client.post(
            f"/api/v1/tasks/{task_id}/start",
            headers=operator_two_headers,
        )
        assert allowed_start.status_code == 200, allowed_start.text

        forbidden_reopen = client.post(
            f"/api/v1/tasks/{task_id}/reopen",
            headers=operator_two_headers,
        )
        assert forbidden_reopen.status_code == 200, forbidden_reopen.text

        null_title = client.patch(
            f"/api/v1/tasks/{task_id}",
            headers=operator_one_headers,
            json={"title": None},
        )
        assert null_title.status_code == 422

        managed = client.get("/api/v1/users/manage", headers=admin_headers)
        assert managed.status_code == 200
        assert any(user["id"] == operator_one_id for user in managed.json())

        deactivate = client.patch(
            f"/api/v1/users/{operator_one_id}",
            headers=admin_headers,
            json={"is_active": False},
        )
        assert deactivate.status_code == 200, deactivate.text
        assert deactivate.json()["is_active"] is False


def test_offline_update_task_and_permission_conflict() -> None:
    from uuid import uuid4

    with TestClient(app) as client:
        admin_headers = _login(client, "admin@example.com", "Admin123!")
        collaborator = client.post(
            "/api/v1/users",
            headers=admin_headers,
            json={
                "name": "Colaborador Sync",
                "email": "sync-user@example.com",
                "password": "Operador123!",
                "is_admin": False,
            },
        )
        assert collaborator.status_code == 201, collaborator.text
        collaborator_headers = _login(
            client,
            "sync-user@example.com",
            "Operador123!",
        )

        task_id = str(uuid4())
        created = client.post(
            "/api/v1/sync/operations",
            headers=admin_headers,
            json={
                "operations": [
                    {
                        "operation_id": str(uuid4()),
                        "operation_type": "CREATE_TASK",
                        "entity_id": task_id,
                        "base_version": 0,
                        "payload": {
                            "title": "Editar sin conexion",
                            "description": None,
                            "priority": "BAJA",
                            "assigned_to_id": None,
                        },
                    }
                ]
            },
        )
        assert created.status_code == 200, created.text
        assert created.json()["results"][0]["task"]["version"] == 1

        updated = client.post(
            "/api/v1/sync/operations",
            headers=admin_headers,
            json={
                "operations": [
                    {
                        "operation_id": str(uuid4()),
                        "operation_type": "UPDATE_TASK",
                        "entity_id": task_id,
                        "base_version": 1,
                        "payload": {
                            "title": "Editada sin conexion",
                            "description": "Cambio sincronizado",
                            "priority": "ALTA",
                            "assigned_to_id": collaborator.json()["id"],
                        },
                    }
                ]
            },
        )
        assert updated.status_code == 200, updated.text
        result = updated.json()["results"][0]
        assert result["status"] == "APPLIED"
        assert result["task"]["title"] == "Editada sin conexion"
        assert result["task"]["version"] == 2

        forbidden_update = client.post(
            "/api/v1/sync/operations",
            headers=collaborator_headers,
            json={
                "operations": [
                    {
                        "operation_id": str(uuid4()),
                        "operation_type": "UPDATE_TASK",
                        "entity_id": task_id,
                        "base_version": 2,
                        "payload": {"title": "No permitido"},
                    }
                ]
            },
        )
        assert forbidden_update.status_code == 200
        assert forbidden_update.json()["results"][0]["status"] == "ERROR"
