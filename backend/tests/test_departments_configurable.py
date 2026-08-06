from uuid import uuid4

from fastapi.testclient import TestClient

from app.main import app


def _login(client: TestClient, email: str, password: str) -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": password},
    )
    assert response.status_code == 200, response.text
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def test_admin_configures_departments_and_user_memberships() -> None:
    suffix = uuid4().hex[:8]
    quality_name = f"Calidad {suffix}"
    support_name = f"Soporte {suffix}"
    user_email = f"multidepto-{suffix}@example.com"
    password = "Operador123!"

    with TestClient(app) as client:
        admin_headers = _login(client, "admin@example.com", "Admin123!")

        quality = client.post(
            "/api/v1/departments",
            headers=admin_headers,
            json={"name": quality_name},
        )
        assert quality.status_code == 201, quality.text
        quality_id = quality.json()["id"]

        support = client.post(
            "/api/v1/departments",
            headers=admin_headers,
            json={"name": support_name},
        )
        assert support.status_code == 201, support.text
        support_id = support.json()["id"]

        created_user = client.post(
            "/api/v1/users",
            headers=admin_headers,
            json={
                "name": "Usuario Multidepartamento",
                "email": user_email,
                "password": password,
                "is_admin": False,
                "department_ids": [quality_id, support_id],
            },
        )
        assert created_user.status_code == 201, created_user.text
        user = created_user.json()
        user_id = user["id"]
        assert set(user["department_ids"]) == {quality_id, support_id}

        quality_detail = client.get(
            f"/api/v1/departments/{quality_id}",
            headers=admin_headers,
        )
        assert quality_detail.status_code == 200, quality_detail.text
        assert user_id in {member["id"] for member in quality_detail.json()["members"]}

        user_headers = _login(client, user_email, password)
        visible_departments = client.get(
            "/api/v1/departments",
            headers=user_headers,
        )
        assert visible_departments.status_code == 200, visible_departments.text
        assert {item["id"] for item in visible_departments.json()} == {
            quality_id,
            support_id,
        }

        forbidden_department = client.post(
            "/api/v1/departments",
            headers=user_headers,
            json={"name": f"No permitido {suffix}"},
        )
        assert forbidden_department.status_code == 403

        task = client.post(
            "/api/v1/tasks",
            headers=user_headers,
            json={
                "title": "Tarea del departamento de calidad",
                "description": "Debe quedar aislada por departamento",
                "priority": "MEDIA",
                "department_id": quality_id,
                "assignee_ids": [user_id],
            },
        )
        assert task.status_code == 201, task.text
        task_id = task.json()["id"]
        assert task.json()["department"]["id"] == quality_id

        quality_tasks = client.get(
            "/api/v1/tasks",
            headers=user_headers,
            params={"department_id": quality_id},
        )
        assert quality_tasks.status_code == 200, quality_tasks.text
        assert task_id in {item["id"] for item in quality_tasks.json()}

        support_tasks = client.get(
            "/api/v1/tasks",
            headers=user_headers,
            params={"department_id": support_id},
        )
        assert support_tasks.status_code == 200, support_tasks.text
        assert task_id not in {item["id"] for item in support_tasks.json()}

        reassigned = client.patch(
            f"/api/v1/users/{user_id}",
            headers=admin_headers,
            json={"department_ids": [support_id]},
        )
        assert reassigned.status_code == 200, reassigned.text
        assert reassigned.json()["department_ids"] == [support_id]

        no_longer_visible = client.get(
            f"/api/v1/tasks/{task_id}",
            headers=user_headers,
        )
        assert no_longer_visible.status_code == 403
