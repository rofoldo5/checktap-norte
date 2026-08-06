from datetime import UTC, datetime
from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.device_registration import DeviceRegistration
from app.models.user import User
from app.schemas.device import (
    DeviceRegistrationDelete,
    DeviceRegistrationRead,
    DeviceRegistrationSummary,
    DeviceRegistrationUpsert,
)

router = APIRouter(prefix="/devices", tags=["devices"])


@router.post("", response_model=DeviceRegistrationRead)
def register_device(
    payload: DeviceRegistrationUpsert,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> DeviceRegistration:
    now = datetime.now(UTC)
    registration = db.scalar(
        select(DeviceRegistration).where(
            DeviceRegistration.registration_id == payload.registration_id
        )
    )

    if registration is None:
        registration = DeviceRegistration(
            user_id=current_user.id,
            registration_id=payload.registration_id,
            registration_kind=payload.registration_kind,
            platform=payload.platform,
            device_name=payload.device_name,
            is_active=True,
            created_at=now,
            updated_at=now,
            last_seen_at=now,
        )
    else:
        # El mismo telefono puede iniciar sesion con otra cuenta. Transferir el
        # registro evita que las notificaciones sigan llegando al usuario anterior.
        registration.user_id = current_user.id
        registration.registration_kind = payload.registration_kind
        registration.platform = payload.platform
        registration.device_name = payload.device_name
        registration.is_active = True
        registration.updated_at = now
        registration.last_seen_at = now
        registration.last_error = None

    db.add(registration)
    db.commit()
    db.refresh(registration)
    return registration


@router.get("", response_model=DeviceRegistrationSummary)
def list_current_devices(
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> DeviceRegistrationSummary:
    registrations = list(
        db.scalars(
            select(DeviceRegistration)
            .where(DeviceRegistration.user_id == current_user.id)
            .order_by(DeviceRegistration.last_seen_at.desc())
        ).all()
    )
    return DeviceRegistrationSummary(
        active_count=sum(item.is_active for item in registrations),
        registrations=registrations,
    )


@router.delete("/current", status_code=status.HTTP_204_NO_CONTENT)
def unregister_current_device(
    payload: DeviceRegistrationDelete,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> None:
    registration = db.scalar(
        select(DeviceRegistration).where(
            DeviceRegistration.user_id == current_user.id,
            DeviceRegistration.registration_id == payload.registration_id,
        )
    )
    if registration is not None:
        db.delete(registration)
        db.commit()
