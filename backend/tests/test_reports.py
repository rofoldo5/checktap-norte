from datetime import date

from fastapi.testclient import TestClient

from app.main import app


def _login(client: TestClient, email: str, password: str) -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": password},
    )
    assert response.status_code == 200, response.text
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def test_generate_list_and_download_department_report() -> None:
    with TestClient(app) as client:
        headers = _login(client, "admin@example.com", "Admin123!")
        created = client.post(
            "/api/v1/tasks",
            headers=headers,
            json={
                "title": "Tarea para informe diario",
                "description": "Debe identificar a la persona que la completo",
                "priority": "MEDIA",
                "assignee_ids": [],
            },
        )
        assert created.status_code == 201, created.text
        task_id = created.json()["id"]
        completed = client.post(
            f"/api/v1/tasks/{task_id}/complete",
            headers=headers,
        )
        assert completed.status_code == 200, completed.text

        generated = client.post(
            "/api/v1/reports/generate",
            headers=headers,
            json={"report_date": date.today().isoformat()},
        )
        assert generated.status_code == 200, generated.text
        data = generated.json()
        assert data["status"] == "READY"
        assert data["completed_count"] >= 1

        listed = client.get("/api/v1/reports", headers=headers)
        assert listed.status_code == 200, listed.text
        assert any(item["id"] == data["id"] for item in listed.json())

        downloaded = client.get(
            f"/api/v1/reports/{data['id']}/download",
            headers=headers,
        )
        assert downloaded.status_code == 200, downloaded.text
        assert downloaded.headers["content-type"].startswith("application/pdf")
        assert downloaded.content.startswith(b"%PDF")
