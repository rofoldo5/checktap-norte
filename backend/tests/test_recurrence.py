from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

from fastapi.testclient import TestClient
from sqlalchemy import create_engine, inspect, text

from app.core.database import SessionLocal
from app.main import app
from app.models.task import Task
from app.services import schema_compat
from app.services.recurrence_service import generate_due_occurrences, next_occurrence


def _login(client: TestClient) -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/login",
        json={"email": "admin@example.com", "password": "Admin123!"},
    )
    assert response.status_code == 200, response.text
    return {"Authorization": f"Bearer {response.json()['access_token']}"}



def test_schema_compat_migration_is_additive_and_idempotent(monkeypatch) -> None:
    legacy_engine = create_engine("sqlite+pysqlite:///:memory:")
    with legacy_engine.begin() as connection:
        connection.execute(
            text(
                "CREATE TABLE tasks ("
                "id VARCHAR(36) PRIMARY KEY, "
                "title VARCHAR(150) NOT NULL"
                ")"
            )
        )

    monkeypatch.setattr(schema_compat, "engine", legacy_engine)
    schema_compat.ensure_recurring_task_schema()
    schema_compat.ensure_recurring_task_schema()

    columns = {
        column["name"] for column in inspect(legacy_engine).get_columns("tasks")
    }
    assert {
        "recurrence_type",
        "recurrence_interval",
        "recurrence_start_at",
        "recurrence_timezone",
        "next_occurrence_at",
        "notifications_enabled",
        "reminder_minutes_before",
        "recurrence_series_id",
        "is_recurrence_master",
        "scheduled_for",
    }.issubset(columns)
    legacy_engine.dispose()

def test_custom_every_fifteen_days_calculates_next_occurrence() -> None:
    start = datetime(2026, 8, 13, 12, 30, tzinfo=UTC)

    result = next_occurrence(
        start,
        recurrence_type="CUSTOM",
        interval=15,
        unit="DAYS",
        timezone_name="America/Santo_Domingo",
        anchor_utc=start,
    )

    assert result == datetime(2026, 8, 28, 12, 30, tzinfo=UTC)


def test_monthly_recurrence_uses_last_available_day_without_losing_anchor() -> None:
    january = datetime(2027, 1, 31, 14, 0, tzinfo=UTC)

    february = next_occurrence(
        january,
        recurrence_type="MONTHLY",
        timezone_name="UTC",
        anchor_utc=january,
    )
    march = next_occurrence(
        february,
        recurrence_type="MONTHLY",
        timezone_name="UTC",
        anchor_utc=january,
    )

    assert february == datetime(2027, 2, 28, 14, 0, tzinfo=UTC)
    assert march == datetime(2027, 3, 31, 14, 0, tzinfo=UTC)


def test_task_api_accepts_recurrence_and_reminder_configuration() -> None:
    with TestClient(app) as client:
        headers = _login(client)
        department_id = client.get(
            "/api/v1/departments", headers=headers
        ).json()[0]["id"]
        starts_at = datetime.now(UTC) + timedelta(days=2)

        response = client.post(
            "/api/v1/tasks",
            headers=headers,
            json={
                "title": f"Revision quincenal {uuid4().hex[:8]}",
                "department_id": department_id,
                "recurrence_type": "CUSTOM",
                "recurrence_interval": 15,
                "recurrence_unit": "DAYS",
                "recurrence_start_at": starts_at.isoformat(),
                "recurrence_timezone": "America/Santo_Domingo",
                "notifications_enabled": True,
                "reminder_minutes_before": 60,
            },
        )

        assert response.status_code == 201, response.text
        task = response.json()
        assert task["recurrence_type"] == "CUSTOM"
        assert task["recurrence_interval"] == 15
        assert task["recurrence_unit"] == "DAYS"
        assert task["recurrence_timezone"] == "America/Santo_Domingo"
        assert task["notifications_enabled"] is True
        assert task["reminder_minutes_before"] == 60
        assert task["is_recurrence_master"] is True
        assert task["recurrence_series_id"] == task["id"]
        assert task["scheduled_for"] is not None
        assert task["next_occurrence_at"] is not None


def test_due_occurrence_clones_checklists_and_resets_subchecks() -> None:
    now = datetime.now(UTC).replace(microsecond=0)
    with TestClient(app) as client:
        headers = _login(client)
        department_id = client.get(
            "/api/v1/departments", headers=headers
        ).json()[0]["id"]
        task_response = client.post(
            "/api/v1/tasks",
            headers=headers,
            json={
                "title": f"Plantilla recurrente {uuid4().hex[:8]}",
                "department_id": department_id,
                "recurrence_type": "DAILY",
                "recurrence_start_at": (now + timedelta(hours=2)).isoformat(),
                "recurrence_timezone": "UTC",
                "notifications_enabled": True,
            },
        )
        assert task_response.status_code == 201, task_response.text
        master = task_response.json()
        master_id = master["id"]

        checklist_response = client.post(
            f"/api/v1/tasks/{master_id}/checklists",
            headers=headers,
            json={
                "title": "Revision operativa",
                "items": [
                    {"title": "Verificar respaldo"},
                    {"title": "Revisar servicios"},
                ],
            },
        )
        assert checklist_response.status_code == 201, checklist_response.text
        checklist = checklist_response.json()["checklists"][0]

        completed = client.post(
            f"/api/v1/tasks/{master_id}/checklists/{checklist['id']}/state",
            headers=headers,
            json={"is_completed": True},
        )
        assert completed.status_code == 200, completed.text
        assert completed.json()["checklists"][0]["completed_count"] == 2

        due_at = now - timedelta(minutes=1)
        with SessionLocal() as db:
            stored = db.get(Task, UUID(master_id))
            assert stored is not None
            stored.next_occurrence_at = due_at
            db.add(stored)
            db.commit()

        with SessionLocal() as db:
            generated = generate_due_occurrences(db, now_utc=now)
            assert len(generated) == 1
            generated_id = generated[0].id

        child_response = client.get(
            f"/api/v1/tasks/{generated_id}", headers=headers
        )
        assert child_response.status_code == 200, child_response.text
        child = child_response.json()
        assert child["id"] != master_id
        assert child["recurrence_series_id"] == master_id
        assert child["is_recurrence_master"] is False
        assert child["status"] == "PENDIENTE"
        assert len(child["checklists"]) == 1
        assert child["checklists"][0]["title"] == "Revision operativa"
        assert child["checklists"][0]["completed_count"] == 0
        assert [item["is_completed"] for item in child["checklists"][0]["items"]] == [
            False,
            False,
        ]
        assert all(
            item["completed_by"] is None
            for item in child["checklists"][0]["items"]
        )

        blocked = client.patch(
            f"/api/v1/tasks/{generated_id}",
            headers=headers,
            json={"recurrence_type": "NONE"},
        )
        assert blocked.status_code == 400, blocked.text
        assert "tarea original" in blocked.json()["detail"].lower()
