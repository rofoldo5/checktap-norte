from fastapi.testclient import TestClient

from app.main import app


def _login(client: TestClient, email: str, password: str) -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": password},
    )
    assert response.status_code == 200, response.text
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def _default_department_id(client: TestClient) -> str:
    response = client.get("/api/v1/auth/registration/departments")
    assert response.status_code == 200, response.text
    departments = response.json()
    assert departments
    assert set(departments[0]) == {"id", "name"}
    return departments[0]["id"]


def test_user_registers_pending_and_admin_approves_access() -> None:
    with TestClient(app) as client:
        department_id = _default_department_id(client)
        registered = client.post(
            "/api/v1/auth/register",
            json={
                "name": "Solicitud Aprobable",
                "email": "solicitud-aprobable@example.com",
                "password": "Solicitud123!",
                "department_id": department_id,
            },
        )
        assert registered.status_code == 201, registered.text
        payload = registered.json()
        assert payload["account_status"] == "PENDING"
        assert payload["department_id"] == department_id

        pending_login = client.post(
            "/api/v1/auth/login",
            json={
                "email": "solicitud-aprobable@example.com",
                "password": "Solicitud123!",
            },
        )
        assert pending_login.status_code == 403
        assert "pendiente" in pending_login.json()["detail"].lower()

        admin_headers = _login(client, "admin@example.com", "Admin123!")
        requests = client.get(
            "/api/v1/users/access-requests",
            headers=admin_headers,
        )
        assert requests.status_code == 200, requests.text
        request = next(
            item
            for item in requests.json()
            if item["email"] == "solicitud-aprobable@example.com"
        )
        assert request["is_active"] is False
        assert request["is_admin"] is False
        assert request["department_ids"] == [department_id]

        approved = client.post(
            f"/api/v1/users/{request['id']}/approve",
            headers=admin_headers,
            json={"department_ids": [department_id], "is_admin": False},
        )
        assert approved.status_code == 200, approved.text
        assert approved.json()["account_status"] == "APPROVED"
        assert approved.json()["is_active"] is True
        assert approved.json()["reviewed_by_id"] is not None

        edited = client.patch(
            f"/api/v1/users/{request['id']}",
            headers=admin_headers,
            json={"name": "Solicitud Ya Aprobada", "is_active": True},
        )
        assert edited.status_code == 200, edited.text
        assert edited.json()["account_status"] == "APPROVED"
        assert edited.json()["is_active"] is True

        approved_login = client.post(
            "/api/v1/auth/login",
            json={
                "email": "solicitud-aprobable@example.com",
                "password": "Solicitud123!",
            },
        )
        assert approved_login.status_code == 200, approved_login.text


def test_admin_can_reject_request_with_reason() -> None:
    with TestClient(app) as client:
        department_id = _default_department_id(client)
        registered = client.post(
            "/api/v1/auth/register",
            json={
                "name": "Solicitud Rechazable",
                "email": "solicitud-rechazable@example.com",
                "password": "Solicitud123!",
                "department_id": department_id,
            },
        )
        assert registered.status_code == 201, registered.text

        admin_headers = _login(client, "admin@example.com", "Admin123!")
        rejected = client.post(
            f"/api/v1/users/{registered.json()['id']}/reject",
            headers=admin_headers,
            json={"reason": "Departamento no confirmado"},
        )
        assert rejected.status_code == 200, rejected.text
        assert rejected.json()["account_status"] == "REJECTED"
        assert rejected.json()["is_active"] is False

        edited = client.patch(
            f"/api/v1/users/{registered.json()['id']}",
            headers=admin_headers,
            json={"name": "Solicitud Rechazada", "is_active": False},
        )
        assert edited.status_code == 200, edited.text
        assert edited.json()["account_status"] == "REJECTED"
        assert edited.json()["review_note"] == "Departamento no confirmado"

        rejected_login = client.post(
            "/api/v1/auth/login",
            json={
                "email": "solicitud-rechazable@example.com",
                "password": "Solicitud123!",
            },
        )
        assert rejected_login.status_code == 403
        assert "Departamento no confirmado" in rejected_login.json()["detail"]


def test_registration_never_accepts_admin_privileges_or_duplicate_email() -> None:
    with TestClient(app) as client:
        department_id = _default_department_id(client)
        malicious = client.post(
            "/api/v1/auth/register",
            json={
                "name": "Intento Admin",
                "email": "intento-admin@example.com",
                "password": "Solicitud123!",
                "department_id": department_id,
                "is_admin": True,
            },
        )
        assert malicious.status_code == 422

        first = client.post(
            "/api/v1/auth/register",
            json={
                "name": "Solicitud Duplicada",
                "email": "solicitud-duplicada@example.com",
                "password": "Solicitud123!",
                "department_id": department_id,
            },
        )
        assert first.status_code == 201, first.text
        duplicate = client.post(
            "/api/v1/auth/register",
            json={
                "name": "Otra Persona",
                "email": "solicitud-duplicada@example.com",
                "password": "OtraClave123!",
                "department_id": department_id,
            },
        )
        assert duplicate.status_code == 409


def test_non_admin_cannot_review_access_requests() -> None:
    with TestClient(app) as client:
        admin_headers = _login(client, "admin@example.com", "Admin123!")
        operator = client.post(
            "/api/v1/users",
            headers=admin_headers,
            json={
                "name": "Operador Sin Permisos",
                "email": "operador-sin-permisos@example.com",
                "password": "Operador123!",
                "is_admin": False,
            },
        )
        assert operator.status_code == 201, operator.text
        operator_headers = _login(
            client,
            "operador-sin-permisos@example.com",
            "Operador123!",
        )
        requests = client.get(
            "/api/v1/users/access-requests",
            headers=operator_headers,
        )
        assert requests.status_code == 403
