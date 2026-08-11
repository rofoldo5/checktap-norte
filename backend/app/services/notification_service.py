from __future__ import annotations

import json
import logging
import threading
import warnings
from collections.abc import Iterable
from dataclasses import dataclass, field
from datetime import UTC, date, datetime
from typing import Any
from uuid import UUID

from sqlalchemy import select

from app.core.config import settings
from app.core.database import SessionLocal
from app.models.checklist import TaskChecklist
from app.models.department import Department, DepartmentMember
from app.models.device_registration import DeviceRegistration
from app.models.notification_event import NotificationDelivery, NotificationEvent
from app.models.task import Task
from app.models.user import ACCOUNT_STATUS_APPROVED, User

logger = logging.getLogger(__name__)


@dataclass(slots=True)
class DeliveryReport:
    attempted: int = 0
    success_count: int = 0
    failure_count: int = 0
    deactivated_count: int = 0
    message_ids: list[str] = field(default_factory=list)
    event_id: UUID | None = None


class FirebaseNotificationService:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._app: Any | None = None
        self._initialization_error: str | None = None

    def initialize(self) -> bool:
        if not settings.firebase_enabled:
            self._initialization_error = "Firebase esta deshabilitado"
            return False

        if self._app is not None:
            return True

        with self._lock:
            if self._app is not None:
                return True
            try:
                import firebase_admin

                try:
                    app = firebase_admin.get_app()
                except ValueError:
                    app = firebase_admin.initialize_app()

                _ = app.project_id
                self._app = app
                self._initialization_error = None
                logger.info("Firebase inicializado para el proyecto %s", app.project_id)
                return True
            except Exception as exc:  # pragma: no cover - depende del entorno
                self._initialization_error = f"{type(exc).__name__}: {exc}"
                logger.exception("No fue posible inicializar Firebase")
                return False

    def status(self) -> dict[str, object]:
        initialized = self.initialize()
        project_id: str | None = None
        if initialized and self._app is not None:
            project_id = self._app.project_id
        return {
            "enabled": settings.firebase_enabled,
            "initialized": initialized,
            "project_id": project_id,
            "error": self._initialization_error,
        }

    def send_to_user(
        self,
        *,
        user_id: UUID,
        title: str,
        body: str,
        data: dict[str, object] | None = None,
    ) -> DeliveryReport:
        if not self.initialize():
            return DeliveryReport()
        with SessionLocal() as db:
            registrations = list(
                db.scalars(
                    select(DeviceRegistration)
                    .where(
                        DeviceRegistration.user_id == user_id,
                        DeviceRegistration.is_active.is_(True),
                    )
                    .order_by(DeviceRegistration.last_seen_at.desc())
                ).all()
            )
            return self._send_registrations(
                db=db,
                registrations=registrations,
                title=title,
                body=body,
                data=data or {},
                event=None,
            )

    def send_to_department(
        self,
        *,
        department_id: UUID,
        event_type: str,
        title: str,
        body: str,
        actor_user_id: UUID | None = None,
        task_id: UUID | None = None,
        report_id: UUID | None = None,
        data: dict[str, object] | None = None,
    ) -> DeliveryReport:
        string_data = {
            str(key): str(value)
            for key, value in (data or {}).items()
            if value is not None
        }
        string_data.setdefault("type", event_type)
        string_data.setdefault("department_id", str(department_id))
        if actor_user_id is not None:
            string_data.setdefault("actor_id", str(actor_user_id))
        if task_id is not None:
            string_data.setdefault("task_id", str(task_id))
        if report_id is not None:
            string_data.setdefault("report_id", str(report_id))

        with SessionLocal() as db:
            event = NotificationEvent(
                department_id=department_id,
                event_type=event_type,
                actor_user_id=actor_user_id,
                task_id=task_id,
                report_id=report_id,
                title=title,
                body=body,
                data_json=json.dumps(string_data, ensure_ascii=False),
            )
            db.add(event)
            db.flush()

            registrations = list(
                db.scalars(
                    select(DeviceRegistration)
                    .join(User, User.id == DeviceRegistration.user_id)
                    .join(
                        DepartmentMember,
                        DepartmentMember.user_id == DeviceRegistration.user_id,
                    )
                    .where(
                        DepartmentMember.department_id == department_id,
                        DepartmentMember.is_active.is_(True),
                        User.is_active.is_(True),
                        DeviceRegistration.is_active.is_(True),
                    )
                    .order_by(DeviceRegistration.last_seen_at.desc())
                )
                .unique()
                .all()
            )
            db.commit()

            if not self.initialize():
                return DeliveryReport(event_id=event.id)

            return self._send_registrations(
                db=db,
                registrations=registrations,
                title=title,
                body=body,
                data=string_data,
                event=event,
            )

    def notify_access_request_created(self, *, user_id: UUID) -> DeliveryReport:
        with SessionLocal() as db:
            user = db.get(User, user_id)
            membership = db.scalar(
                select(DepartmentMember)
                .where(
                    DepartmentMember.user_id == user_id,
                    DepartmentMember.is_active.is_(True),
                )
                .order_by(DepartmentMember.created_at.asc())
            )
            if user is None or membership is None:
                return DeliveryReport()
            department = db.get(Department, membership.department_id)
            if department is None:
                return DeliveryReport()

            data = {
                "type": "access_request_created",
                "request_id": str(user.id),
                "user_name": user.name,
                "department_id": str(department.id),
                "department_name": department.name,
            }
            event = NotificationEvent(
                department_id=department.id,
                event_type="access_request_created",
                actor_user_id=user.id,
                title="Nueva solicitud de acceso",
                body=f"{user.name} solicita acceso a {department.name}.",
                data_json=json.dumps(data, ensure_ascii=False),
            )
            db.add(event)
            db.flush()

            registrations = list(
                db.scalars(
                    select(DeviceRegistration)
                    .join(User, User.id == DeviceRegistration.user_id)
                    .where(
                        User.is_admin.is_(True),
                        User.is_active.is_(True),
                        User.account_status == ACCOUNT_STATUS_APPROVED,
                        DeviceRegistration.is_active.is_(True),
                    )
                    .order_by(DeviceRegistration.last_seen_at.desc())
                ).all()
            )
            db.commit()

            if not self.initialize():
                return DeliveryReport(event_id=event.id)
            return self._send_registrations(
                db=db,
                registrations=registrations,
                title=event.title,
                body=event.body,
                data=data,
                event=event,
            )

    def notify_access_request_reviewed(
        self,
        *,
        user_id: UUID,
        reviewer_id: UUID,
        approved: bool,
        reason: str | None = None,
    ) -> DeliveryReport:
        with SessionLocal() as db:
            user = db.get(User, user_id)
            membership = db.scalar(
                select(DepartmentMember)
                .where(
                    DepartmentMember.user_id == user_id,
                    DepartmentMember.is_active.is_(True),
                )
                .order_by(DepartmentMember.created_at.asc())
            )
            if user is None or membership is None:
                return DeliveryReport()
            department = db.get(Department, membership.department_id)
            if department is None:
                return DeliveryReport()

            if approved:
                event_type = "access_request_approved"
                title = "Acceso aprobado"
                body = "Tu acceso a CheckTap fue aprobado. Ya puedes iniciar sesión."
            else:
                event_type = "access_request_rejected"
                title = "Solicitud revisada"
                body = "Tu solicitud de acceso a CheckTap fue rechazada."
                if reason:
                    body = f"{body} Motivo: {reason}"

            data = {
                "type": event_type,
                "user_id": str(user.id),
                "account_status": "APPROVED" if approved else "REJECTED",
                "department_id": str(department.id),
                "department_name": department.name,
            }
            if reason:
                data["reason"] = reason

            event = NotificationEvent(
                department_id=department.id,
                event_type=event_type,
                actor_user_id=reviewer_id,
                title=title,
                body=body,
                data_json=json.dumps(data, ensure_ascii=False),
            )
            db.add(event)
            db.flush()
            registrations = list(
                db.scalars(
                    select(DeviceRegistration)
                    .where(
                        DeviceRegistration.user_id == user.id,
                        DeviceRegistration.is_active.is_(True),
                    )
                    .order_by(DeviceRegistration.last_seen_at.desc())
                ).all()
            )
            db.commit()

            if not self.initialize():
                return DeliveryReport(event_id=event.id)
            return self._send_registrations(
                db=db,
                registrations=registrations,
                title=title,
                body=body,
                data=data,
                event=event,
            )

    def notify_task_event(
        self,
        *,
        event_type: str,
        task_id: UUID,
        actor_id: UUID,
    ) -> DeliveryReport:
        with SessionLocal() as db:
            task = db.get(Task, task_id)
            actor = db.get(User, actor_id)
            if task is None or actor is None:
                return DeliveryReport()
            department = db.get(Department, task.department_id)
            if department is None:
                return DeliveryReport()

            title: str
            body: str
            if event_type == "task_created":
                title = f"Nueva tarea en {department.name}"
                body = f'{actor.name} creo "{task.title}".'
            elif event_type == "task_updated":
                title = f"Tarea actualizada en {department.name}"
                body = f'{actor.name} actualizo "{task.title}".'
            elif event_type == "task_started":
                title = f"Tarea iniciada en {department.name}"
                body = f'{actor.name} inicio "{task.title}".'
            elif event_type == "task_completed":
                title = f"Tarea completada en {department.name}"
                body = f'{actor.name} completo "{task.title}".'
            elif event_type == "task_reopened":
                title = f"Tarea reabierta en {department.name}"
                body = f'{actor.name} reabrio "{task.title}".'
            else:
                return DeliveryReport()

        return self.send_to_department(
            department_id=task.department_id,
            event_type=event_type,
            title=title,
            body=body,
            actor_user_id=actor_id,
            task_id=task_id,
            data={
                "task_title": task.title,
                "department_name": department.name,
                "actor_name": actor.name,
            },
        )

    def notify_checklist_completed(
        self,
        *,
        task_id: UUID,
        checklist_id: UUID,
        actor_id: UUID,
    ) -> DeliveryReport:
        with SessionLocal() as db:
            task = db.get(Task, task_id)
            checklist = db.get(TaskChecklist, checklist_id)
            actor = db.get(User, actor_id)
            if task is None or checklist is None or actor is None:
                return DeliveryReport()
            if checklist.task_id != task.id:
                return DeliveryReport()
            department = db.get(Department, task.department_id)
            if department is None:
                return DeliveryReport()
            task_title = task.title
            checklist_title = checklist.title
            department_name = department.name

        return self.send_to_department(
            department_id=task.department_id,
            event_type="checklist_completed",
            title=f"Checklist completado en {department_name}",
            body=(
                f'{actor.name} completo "{checklist_title}" en la tarea "{task_title}".'
            ),
            actor_user_id=actor_id,
            task_id=task_id,
            data={
                "task_title": task_title,
                "checklist_id": str(checklist_id),
                "checklist_title": checklist_title,
                "department_name": department_name,
                "actor_name": actor.name,
            },
        )

    def notify_report_ready(
        self,
        *,
        department_id: UUID,
        report_id: UUID,
        report_date: date,
    ) -> DeliveryReport:
        with SessionLocal() as db:
            department = db.get(Department, department_id)
            if department is None:
                return DeliveryReport()
            department_name = department.name
        return self.send_to_department(
            department_id=department_id,
            event_type="daily_report_ready",
            title="Resumen diario disponible",
            body=(
                f"El informe de {department_name} del "
                f"{report_date.strftime('%d/%m/%Y')} esta listo."
            ),
            report_id=report_id,
            data={
                "department_name": department_name,
                "report_date": report_date.isoformat(),
            },
        )

    def _send_registrations(
        self,
        *,
        db: Any,
        registrations: list[DeviceRegistration],
        title: str,
        body: str,
        data: dict[str, object],
        event: NotificationEvent | None,
    ) -> DeliveryReport:
        report = DeliveryReport(
            attempted=len(registrations),
            event_id=event.id if event is not None else None,
        )
        if not registrations or not self.initialize():
            return report

        from firebase_admin import messaging

        string_data = {
            str(key): str(value) for key, value in data.items() if value is not None
        }
        now = datetime.now(UTC)

        for chunk in self._chunks(registrations, 500):
            messages = [
                self._build_message(
                    messaging=messaging,
                    registration=registration,
                    title=title,
                    body=body,
                    data=string_data,
                )
                for registration in chunk
            ]
            try:
                with warnings.catch_warnings():
                    warnings.filterwarnings(
                        "ignore",
                        category=DeprecationWarning,
                        message="Message.token is deprecated.*",
                    )
                    batch = messaging.send_each(messages, app=self._app)
            except Exception as exc:  # pragma: no cover - red/Firebase
                message = f"{type(exc).__name__}: {exc}"[:2000]
                report.failure_count += len(chunk)
                for registration in chunk:
                    registration.last_error = message
                    registration.updated_at = now
                    self._add_delivery(
                        db,
                        event=event,
                        registration=registration,
                        status="FAILED",
                        error=message,
                    )
                logger.exception("Fallo general enviando notificaciones FCM")
                continue

            for registration, response in zip(chunk, batch.responses, strict=True):
                registration.updated_at = now
                if response.success:
                    report.success_count += 1
                    registration.last_success_at = now
                    registration.last_error = None
                    if response.message_id:
                        report.message_ids.append(response.message_id)
                    self._add_delivery(
                        db,
                        event=event,
                        registration=registration,
                        status="SENT",
                        firebase_message_id=response.message_id,
                    )
                    continue

                report.failure_count += 1
                error = response.exception
                error_text = (
                    f"{type(error).__name__}: {error}"[:2000]
                    if error is not None
                    else "Error FCM sin detalle"
                )
                registration.last_error = error_text
                if isinstance(error, messaging.UnregisteredError):
                    registration.is_active = False
                    report.deactivated_count += 1
                self._add_delivery(
                    db,
                    event=event,
                    registration=registration,
                    status="FAILED",
                    error=error_text,
                )

        db.commit()
        return report

    @staticmethod
    def _add_delivery(
        db: Any,
        *,
        event: NotificationEvent | None,
        registration: DeviceRegistration,
        status: str,
        firebase_message_id: str | None = None,
        error: str | None = None,
    ) -> None:
        if event is None:
            return
        db.add(
            NotificationDelivery(
                event_id=event.id,
                device_registration_id=registration.id,
                user_id=registration.user_id,
                status=status,
                firebase_message_id=firebase_message_id,
                error=error,
            )
        )

    @staticmethod
    def _chunks(
        items: list[DeviceRegistration], size: int
    ) -> Iterable[list[DeviceRegistration]]:
        for index in range(0, len(items), size):
            yield items[index : index + size]

    @staticmethod
    def _build_message(
        *,
        messaging: Any,
        registration: DeviceRegistration,
        title: str,
        body: str,
        data: dict[str, str],
    ) -> Any:
        recipient: dict[str, str]
        if registration.registration_kind == "FID":
            recipient = {"fid": registration.registration_id}
        else:
            recipient = {"token": registration.registration_id}

        with warnings.catch_warnings():
            warnings.filterwarnings(
                "ignore",
                category=DeprecationWarning,
                message="Message.token is deprecated.*",
            )
            return messaging.Message(
                notification=messaging.Notification(title=title, body=body),
                data=data,
                android=messaging.AndroidConfig(
                    priority="high",
                    notification=messaging.AndroidNotification(
                        channel_id=settings.firebase_android_channel_id,
                        sound="default",
                    ),
                ),
                **recipient,
            )


notification_service = FirebaseNotificationService()
