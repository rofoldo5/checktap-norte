from uuid import UUID, uuid4

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


def test_device_registration_and_test_endpoint(monkeypatch) -> None:
    registration_id = "test-registration-" + ("x" * 80)

    def fake_send_to_user(**kwargs) -> DeliveryReport:
        return DeliveryReport(
            attempted=1,
            success_count=1,
            failure_count=0,
            message_ids=["projects/test/messages/123"],
        )

    monkeypatch.setattr(notification_service, "send_to_user", fake_send_to_user)

    with TestClient(app) as client:
        headers = _login(client, "admin@example.com", "Admin123!")
        registered = client.post(
            "/api/v1/devices",
            headers=headers,
            json={
                "registration_id": registration_id,
                "registration_kind": "TOKEN",
                "platform": "android",
                "device_name": "Android de prueba",
            },
        )
        assert registered.status_code == 200, registered.text
        assert registered.json()["is_active"] is True

        listed = client.get("/api/v1/devices", headers=headers)
        assert listed.status_code == 200, listed.text
        assert listed.json()["active_count"] >= 1

        sent = client.post("/api/v1/notifications/test", headers=headers)
        assert sent.status_code == 200, sent.text
        assert sent.json()["success_count"] == 1

        deleted = client.request(
            "DELETE",
            "/api/v1/devices/current",
            headers=headers,
            json={"registration_id": registration_id},
        )
        assert deleted.status_code == 204, deleted.text


def test_task_creation_schedules_department_notification(monkeypatch) -> None:
    calls: list[dict[str, object]] = []

    def fake_notify_task_event(**kwargs) -> DeliveryReport:
        calls.append(kwargs)
        return DeliveryReport()

    monkeypatch.setattr(
        notification_service,
        "notify_task_event",
        fake_notify_task_event,
    )

    with TestClient(app) as client:
        headers = _login(client, "admin@example.com", "Admin123!")
        suffix = uuid4().hex[:8]
        created_user = client.post(
            "/api/v1/users",
            headers=headers,
            json={
                "name": "Usuario Notificaciones",
                "email": f"notify-{suffix}@example.com",
                "password": "Operador123!",
                "is_admin": False,
            },
        )
        assert created_user.status_code == 201, created_user.text

        created_task = client.post(
            "/api/v1/tasks",
            headers=headers,
            json={
                "title": "Validar aviso automatico",
                "description": None,
                "priority": "MEDIA",
                "assigned_to_id": created_user.json()["id"],
            },
        )
        assert created_task.status_code == 201, created_task.text
        assert len(calls) == 1
        assert calls[0]["event_type"] == "task_created"
        assert str(calls[0]["task_id"]) == created_task.json()["id"]


def test_department_broadcast_includes_actor_and_all_members(monkeypatch) -> None:
    calls: list[dict[str, object]] = []

    def fake_send_to_department(**kwargs) -> DeliveryReport:
        calls.append(kwargs)
        return DeliveryReport(attempted=5, success_count=5)

    monkeypatch.setattr(
        notification_service,
        "send_to_department",
        fake_send_to_department,
    )

    with TestClient(app) as client:
        headers = _login(client, "admin@example.com", "Admin123!")
        task = client.post(
            "/api/v1/tasks",
            headers=headers,
            json={
                "title": "Aviso para todo el equipo",
                "description": None,
                "priority": "ALTA",
                "assignee_ids": [],
            },
        )
        assert task.status_code == 201, task.text
        assert len(calls) == 1
        calls.clear()

        result = notification_service.notify_task_event(
            event_type="task_created",
            task_id=UUID(task.json()["id"]),
            actor_id=UUID(task.json()["created_by"]["id"]),
        )
        assert result.attempted == 5
        assert len(calls) == 1
        assert calls[0]["department_id"] == UUID(task.json()["department"]["id"])
        assert calls[0]["actor_user_id"] == UUID(task.json()["created_by"]["id"])
        assert "creo" in str(calls[0]["body"])


def test_department_send_targets_all_five_registered_members(monkeypatch) -> None:
    captured_user_ids: list[object] = []

    def fake_initialize() -> bool:
        return True

    def fake_send_registrations(**kwargs) -> DeliveryReport:
        registrations = kwargs["registrations"]
        captured_user_ids.extend(item.user_id for item in registrations)
        event = kwargs["event"]
        return DeliveryReport(
            attempted=len(registrations),
            success_count=len(registrations),
            event_id=event.id,
        )

    monkeypatch.setattr(notification_service, "initialize", fake_initialize)
    monkeypatch.setattr(
        notification_service,
        "_send_registrations",
        fake_send_registrations,
    )

    with TestClient(app) as client:
        admin_headers = _login(client, "admin@example.com", "Admin123!")
        member_headers: list[dict[str, str]] = []
        member_ids: list[str] = []

        for index in range(5):
            suffix = uuid4().hex[:8]
            email = f"equipo-{index}-{suffix}@example.com"
            password = "Operador123!"
            created = client.post(
                "/api/v1/users",
                headers=admin_headers,
                json={
                    "name": f"Integrante {index + 1}",
                    "email": email,
                    "password": password,
                    "is_admin": False,
                },
            )
            assert created.status_code == 201, created.text
            member_ids.append(created.json()["id"])
            headers = _login(client, email, password)
            member_headers.append(headers)
            registered = client.post(
                "/api/v1/devices",
                headers=headers,
                json={
                    "registration_id": f"member-{index}-" + ("t" * 90),
                    "registration_kind": "TOKEN",
                    "platform": "android",
                    "device_name": f"Telefono {index + 1}",
                },
            )
            assert registered.status_code == 200, registered.text

        sent = client.post(
            "/api/v1/notifications/test-department",
            headers=member_headers[0],
            json={},
        )
        assert sent.status_code == 200, sent.text
        assert sent.json()["attempted"] == 5
        assert sent.json()["success_count"] == 5
        assert {str(item) for item in captured_user_ids} == set(member_ids)
        assert member_ids[0] in {str(item) for item in captured_user_ids}


def test_new_access_request_targets_all_registered_admins(monkeypatch) -> None:
    captured_user_ids: list[str] = []
    captured_data: list[dict[str, object]] = []

    def fake_initialize() -> bool:
        return True

    def fake_send_registrations(**kwargs) -> DeliveryReport:
        registrations = kwargs["registrations"]
        captured_user_ids.extend(str(item.user_id) for item in registrations)
        captured_data.append(dict(kwargs["data"]))
        return DeliveryReport(
            attempted=len(registrations),
            success_count=len(registrations),
            event_id=kwargs["event"].id,
        )

    monkeypatch.setattr(notification_service, "initialize", fake_initialize)
    monkeypatch.setattr(
        notification_service,
        "_send_registrations",
        fake_send_registrations,
    )

    with TestClient(app) as client:
        admin_headers = _login(client, "admin@example.com", "Admin123!")
        first_admin = client.get("/api/v1/auth/me", headers=admin_headers).json()
        first_registration = client.post(
            "/api/v1/devices",
            headers=admin_headers,
            json={
                "registration_id": "request-admin-one-" + ("a" * 80),
                "registration_kind": "TOKEN",
                "platform": "android",
                "device_name": "Administrador uno",
            },
        )
        assert first_registration.status_code == 200, first_registration.text

        suffix = uuid4().hex[:8]
        second_email = f"admin-requests-{suffix}@example.com"
        second_admin = client.post(
            "/api/v1/users",
            headers=admin_headers,
            json={
                "name": "Segundo Administrador",
                "email": second_email,
                "password": "Administrador123!",
                "is_admin": True,
            },
        )
        assert second_admin.status_code == 201, second_admin.text
        second_headers = _login(client, second_email, "Administrador123!")
        second_registration = client.post(
            "/api/v1/devices",
            headers=second_headers,
            json={
                "registration_id": "request-admin-two-" + ("b" * 80),
                "registration_kind": "TOKEN",
                "platform": "android",
                "device_name": "Administrador dos",
            },
        )
        assert second_registration.status_code == 200, second_registration.text

        department_id = client.get("/api/v1/auth/registration/departments").json()[0][
            "id"
        ]
        registered = client.post(
            "/api/v1/auth/register",
            json={
                "name": "Solicitud Para Administradores",
                "email": f"request-notify-{suffix}@example.com",
                "password": "Solicitud123!",
                "department_id": department_id,
            },
        )
        assert registered.status_code == 201, registered.text

        assert set(captured_user_ids) == {
            first_admin["id"],
            second_admin.json()["id"],
        }
        assert captured_data[-1]["type"] == "access_request_created"
        assert captured_data[-1]["request_id"] == registered.json()["id"]
