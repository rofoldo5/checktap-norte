from uuid import uuid4

from fastapi.testclient import TestClient

from app.main import app
from app.services.notification_service import DeliveryReport, notification_service


def _login(client: TestClient, email: str, password: str) -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": password},
    )
    assert response.status_code == 200, response.text
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def test_task_checklists_support_items_progress_and_actor(monkeypatch) -> None:
    notifications: list[dict[str, object]] = []

    def fake_notify_checklist_completed(**kwargs) -> DeliveryReport:
        notifications.append(kwargs)
        return DeliveryReport()

    monkeypatch.setattr(
        notification_service,
        "notify_checklist_completed",
        fake_notify_checklist_completed,
    )

    with TestClient(app) as client:
        headers = _login(client, "admin@example.com", "Admin123!")
        departments = client.get("/api/v1/departments", headers=headers)
        assert departments.status_code == 200, departments.text
        department_id = departments.json()[0]["id"]

        task_response = client.post(
            "/api/v1/tasks",
            headers=headers,
            json={
                "title": f"Checklist {uuid4().hex[:8]}",
                "priority": "MEDIA",
                "department_id": department_id,
            },
        )
        assert task_response.status_code == 201, task_response.text
        task_id = task_response.json()["id"]

        checklist_response = client.post(
            f"/api/v1/tasks/{task_id}/checklists",
            headers=headers,
            json={
                "title": "Preparación de producción",
                "items": [
                    {"title": "Validar respaldo"},
                    {"title": "Revisar sincronización"},
                ],
            },
        )
        assert checklist_response.status_code == 201, checklist_response.text
        checklist = checklist_response.json()["checklists"][0]
        checklist_id = checklist["id"]
        first_item_id = checklist["items"][0]["id"]
        assert checklist["item_count"] == 2
        assert checklist["completed_count"] == 0
        assert checklist["is_completed"] is False

        first_done = client.post(
            f"/api/v1/tasks/{task_id}/checklists/{checklist_id}/items/{first_item_id}/state",
            headers=headers,
            json={"is_completed": True},
        )
        assert first_done.status_code == 200, first_done.text
        checklist = first_done.json()["checklists"][0]
        assert checklist["completed_count"] == 1
        assert checklist["is_completed"] is False
        assert checklist["items"][0]["completed_by"]["email"] == "admin@example.com"
        assert notifications == []

        complete_all = client.post(
            f"/api/v1/tasks/{task_id}/checklists/{checklist_id}/state",
            headers=headers,
            json={"is_completed": True},
        )
        assert complete_all.status_code == 200, complete_all.text
        checklist = complete_all.json()["checklists"][0]
        assert checklist["completed_count"] == 2
        assert checklist["is_completed"] is True
        assert len(notifications) == 1
        assert notifications[0]["task_id"] == task_response.json()["id"] or str(
            notifications[0]["task_id"]
        ) == task_id

        reopen_all = client.post(
            f"/api/v1/tasks/{task_id}/checklists/{checklist_id}/state",
            headers=headers,
            json={"is_completed": False},
        )
        assert reopen_all.status_code == 200, reopen_all.text
        checklist = reopen_all.json()["checklists"][0]
        assert checklist["completed_count"] == 0
        assert checklist["is_completed"] is False


def test_completed_task_locks_checklist_changes() -> None:
    with TestClient(app) as client:
        headers = _login(client, "admin@example.com", "Admin123!")
        department_id = client.get(
            "/api/v1/departments", headers=headers
        ).json()[0]["id"]
        task = client.post(
            "/api/v1/tasks",
            headers=headers,
            json={
                "title": f"Tarea cerrada {uuid4().hex[:8]}",
                "department_id": department_id,
            },
        )
        assert task.status_code == 201, task.text
        task_id = task.json()["id"]
        completed = client.post(f"/api/v1/tasks/{task_id}/complete", headers=headers)
        assert completed.status_code == 200, completed.text

        blocked = client.post(
            f"/api/v1/tasks/{task_id}/checklists",
            headers=headers,
            json={"title": "No permitido"},
        )
        assert blocked.status_code == 409, blocked.text


def test_checklist_operations_sync_offline_and_are_idempotent(monkeypatch) -> None:
    notifications: list[dict[str, object]] = []

    def fake_notify_checklist_completed(**kwargs) -> DeliveryReport:
        notifications.append(kwargs)
        return DeliveryReport()

    monkeypatch.setattr(
        notification_service,
        "notify_checklist_completed",
        fake_notify_checklist_completed,
    )

    with TestClient(app) as client:
        headers = _login(client, "admin@example.com", "Admin123!")
        department_id = client.get(
            "/api/v1/departments", headers=headers
        ).json()[0]["id"]
        task = client.post(
            "/api/v1/tasks",
            headers=headers,
            json={
                "title": f"Checklist offline {uuid4().hex[:8]}",
                "department_id": department_id,
            },
        )
        assert task.status_code == 201, task.text
        task_id = task.json()["id"]
        base_version = task.json()["version"]
        checklist_id = str(uuid4())
        item_id = str(uuid4())
        operation_id = str(uuid4())
        create_payload = {
            "operations": [
                {
                    "operation_id": operation_id,
                    "operation_type": "CREATE_CHECKLIST",
                    "entity_id": task_id,
                    "base_version": base_version,
                    "payload": {
                        "id": checklist_id,
                        "title": "Validación offline",
                        "items": [
                            {
                                "id": item_id,
                                "title": "Sincronizar actividad",
                                "position": 0,
                            }
                        ],
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
        assert created_result["task"]["checklists"][0]["id"] == checklist_id

        duplicate = client.post(
            "/api/v1/sync/operations",
            headers=headers,
            json=create_payload,
        )
        assert duplicate.status_code == 200, duplicate.text
        assert duplicate.json()["results"][0] == created_result

        completed = client.post(
            "/api/v1/sync/operations",
            headers=headers,
            json={
                "operations": [
                    {
                        "operation_id": str(uuid4()),
                        "operation_type": "SET_CHECKLIST_ITEM_STATE",
                        "entity_id": task_id,
                        "base_version": created_result["task"]["version"],
                        "payload": {
                            "checklist_id": checklist_id,
                            "item_id": item_id,
                            "is_completed": True,
                        },
                    }
                ]
            },
        )
        assert completed.status_code == 200, completed.text
        completed_result = completed.json()["results"][0]
        assert completed_result["status"] == "APPLIED"
        checklist = completed_result["task"]["checklists"][0]
        assert checklist["is_completed"] is True
        assert checklist["items"][0]["completed_by"]["email"] == "admin@example.com"
        assert len(notifications) == 1
