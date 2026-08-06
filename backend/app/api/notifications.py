from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.department import Department
from app.models.device_registration import DeviceRegistration
from app.models.user import User
from app.schemas.notification import (
    DepartmentNotificationTest,
    NotificationSendResult,
    NotificationStatus,
)
from app.services.department_service import (
    active_department_ids,
    require_department_access,
    resolve_task_department,
)
from app.services.notification_service import notification_service

router = APIRouter(prefix="/notifications", tags=["notifications"])


def _result(report) -> NotificationSendResult:
    return NotificationSendResult(
        attempted=report.attempted,
        success_count=report.success_count,
        failure_count=report.failure_count,
        deactivated_count=report.deactivated_count,
        message_ids=report.message_ids,
        event_id=report.event_id,
    )


@router.get("/status", response_model=NotificationStatus)
def notification_status(
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> NotificationStatus:
    active_count = db.scalar(
        select(func.count(DeviceRegistration.id)).where(
            DeviceRegistration.user_id == current_user.id,
            DeviceRegistration.is_active.is_(True),
        )
    )
    service_status = notification_service.status()
    return NotificationStatus(
        **service_status,
        active_registrations=int(active_count or 0),
    )


@router.post("/test", response_model=NotificationSendResult)
def send_test_notification(
    current_user: Annotated[User, Depends(get_current_user)],
) -> NotificationSendResult:
    report = notification_service.send_to_user(
        user_id=current_user.id,
        title="CheckTap",
        body="Las notificaciones automaticas estan funcionando.",
        data={"type": "test", "source": "checktap-api"},
    )
    return _result(report)


@router.post("/test-department", response_model=NotificationSendResult)
def send_department_test_notification(
    payload: DepartmentNotificationTest,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> NotificationSendResult:
    if payload.department_id is not None:
        require_department_access(current_user, payload.department_id)
        department = db.get(Department, payload.department_id)
    else:
        department = resolve_task_department(db, current_user, None)
    assert department is not None
    report = notification_service.send_to_department(
        department_id=department.id,
        event_type="department_test",
        title=f"Prueba de equipo: {department.name}",
        body=(
            f"{current_user.name} envio una prueba a todos los dispositivos "
            "activos del departamento."
        ),
        actor_user_id=current_user.id,
        data={"source": "checktap-api", "actor_name": current_user.name},
    )
    return _result(report)
