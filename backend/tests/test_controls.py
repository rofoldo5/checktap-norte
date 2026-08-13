from datetime import UTC, datetime, timedelta
from uuid import uuid4

from fastapi.testclient import TestClient

from app.main import app


def _login(client: TestClient, email: str = "admin@example.com", password: str = "Admin123!") -> dict[str, str]:
    response = client.post("/api/v1/auth/login", json={"email": email, "password": password})
    assert response.status_code == 200, response.text
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def _department_id(client: TestClient, headers: dict[str, str]) -> str:
    response = client.get("/api/v1/departments", headers=headers)
    assert response.status_code == 200, response.text
    return response.json()[0]["id"]


def test_control_section_check_reminders_history_and_recurrence() -> None:
    with TestClient(app) as client:
        headers = _login(client)
        department_id = _department_id(client, headers)
        suffix = uuid4().hex[:8]

        section_response = client.post(
            "/api/v1/controls/sections",
            headers=headers,
            json={
                "name": f"Dominios {suffix}",
                "description": "Renovaciones de dominios y servicios web",
                "icon_key": "language",
                "department_id": department_id,
            },
        )
        assert section_response.status_code == 201, section_response.text
        section = section_response.json()
        section_id = section["id"]
        assert section["check_count"] == 0

        due_at = datetime.now(UTC) + timedelta(days=20)
        check_response = client.post(
            f"/api/v1/controls/sections/{section_id}/checks",
            headers=headers,
            json={
                "title": "Renovar www.credinorte.net",
                "description": "Dominio principal",
                "reference": "www.credinorte.net",
                "contact": "norteconectaweb@gmail.com",
                "priority": "ALTA",
                "due_at": due_at.isoformat(),
                "timezone": "America/Caracas",
                "reminder_minutes": [43200, 21600, 10080, 1440],
                "recurrence_type": "YEARLY",
            },
        )
        assert check_response.status_code == 201, check_response.text
        check = check_response.json()
        check_id = check["id"]
        assert check["section_id"] == section_id
        assert check["reminder_minutes"] == [43200, 21600, 10080, 1440]
        assert check["recurrence_type"] == "YEARLY"
        assert check["status"] == "PENDIENTE"
        assert check["due_state"] == "PROXIMA"
        assert check["next_reminder_at"] is not None

        sections = client.get("/api/v1/controls/sections", headers=headers)
        assert sections.status_code == 200, sections.text
        stored_section = next(item for item in sections.json() if item["id"] == section_id)
        assert stored_section["check_count"] == 1
        assert stored_section["upcoming_count"] == 1

        completed = client.post(
            f"/api/v1/controls/checks/{check_id}/complete",
            headers=headers,
            json={"notes": "Renovado por un ano"},
        )
        assert completed.status_code == 200, completed.text
        completed_check = completed.json()
        assert completed_check["status"] == "PENDIENTE"
        assert len(completed_check["history"]) == 1
        assert completed_check["history"][0]["completion_notes"] == "Renovado por un ano"
        next_due = datetime.fromisoformat(completed_check["due_at"])
        assert next_due > due_at + timedelta(days=360)


def test_non_recurring_control_can_complete_and_reopen() -> None:
    with TestClient(app) as client:
        headers = _login(client)
        department_id = _department_id(client, headers)
        suffix = uuid4().hex[:8]
        section = client.post(
            "/api/v1/controls/sections",
            headers=headers,
            json={"name": f"Servidores {suffix}", "department_id": department_id},
        ).json()
        created = client.post(
            f"/api/v1/controls/sections/{section['id']}/checks",
            headers=headers,
            json={
                "title": "Revisar servidor de respaldos",
                "due_at": (datetime.now(UTC) + timedelta(days=2)).isoformat(),
                "timezone": "UTC",
                "reminder_minutes": [1440, 60],
            },
        )
        assert created.status_code == 201, created.text
        check_id = created.json()["id"]

        completed = client.post(
            f"/api/v1/controls/checks/{check_id}/complete",
            headers=headers,
            json={},
        )
        assert completed.status_code == 200, completed.text
        assert completed.json()["status"] == "COMPLETADA"
        assert completed.json()["due_state"] == "COMPLETADA"

        reopened = client.post(
            f"/api/v1/controls/checks/{check_id}/reopen",
            headers=headers,
        )
        assert reopened.status_code == 200, reopened.text
        assert reopened.json()["status"] == "PENDIENTE"
        assert len(reopened.json()["history"]) == 1


def test_control_permissions_and_offline_sync() -> None:
    with TestClient(app) as client:
        admin_headers = _login(client)
        department_id = _department_id(client, admin_headers)
        suffix = uuid4().hex[:8]

        user_response = client.post(
            "/api/v1/users",
            headers=admin_headers,
            json={
                "name": "Operador Controles",
                "email": f"controles-{suffix}@example.com",
                "password": "Operador123!",
                "is_admin": False,
                "department_ids": [department_id],
            },
        )
        assert user_response.status_code == 201, user_response.text
        user_id = user_response.json()["id"]
        user_headers = _login(client, f"controles-{suffix}@example.com", "Operador123!")

        forbidden = client.post(
            "/api/v1/controls/sections",
            headers=user_headers,
            json={"name": f"No permitido {suffix}", "department_id": department_id},
        )
        assert forbidden.status_code == 403

        section_id = str(uuid4())
        sync_section = client.post(
            "/api/v1/sync/operations",
            headers=admin_headers,
            json={
                "operations": [
                    {
                        "operation_id": str(uuid4()),
                        "operation_type": "CREATE_CONTROL_SECTION",
                        "entity_id": section_id,
                        "base_version": 0,
                        "payload": {
                            "name": f"Mantenimientos {suffix}",
                            "department_id": department_id,
                            "icon_key": "build",
                        },
                    }
                ]
            },
        )
        assert sync_section.status_code == 200, sync_section.text
        result = sync_section.json()["results"][0]
        assert result["status"] == "APPLIED"
        assert result["control_section"]["id"] == section_id

        check_id = str(uuid4())
        sync_check = client.post(
            "/api/v1/sync/operations",
            headers=user_headers,
            json={
                "operations": [
                    {
                        "operation_id": str(uuid4()),
                        "operation_type": "CREATE_CONTROL_CHECK",
                        "entity_id": check_id,
                        "base_version": 0,
                        "payload": {
                            "section_id": section_id,
                            "title": "Mantenimiento UPS",
                            "due_at": (datetime.now(UTC) + timedelta(days=5)).isoformat(),
                            "timezone": "UTC",
                            "reminder_minutes": [10080, 1440],
                            "assignee_ids": [user_id],
                        },
                    }
                ]
            },
        )
        assert sync_check.status_code == 200, sync_check.text
        check_result = sync_check.json()["results"][0]
        assert check_result["status"] == "APPLIED"
        assert check_result["control_check"]["id"] == check_id
        assert check_result["control_check"]["assignees"][0]["id"] == user_id
