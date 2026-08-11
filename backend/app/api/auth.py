from datetime import UTC, datetime
from typing import Annotated

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.security import create_access_token, hash_password, verify_password
from app.models.department import Department, DepartmentMember
from app.models.device_registration import DeviceRegistration
from app.models.user import (
    ACCOUNT_STATUS_APPROVED,
    ACCOUNT_STATUS_PENDING,
    ACCOUNT_STATUS_REJECTED,
    ACCOUNT_STATUS_SUSPENDED,
    User,
)
from app.schemas.auth import (
    LoginRequest,
    RegistrationDepartment,
    RegistrationRequest,
    RegistrationResponse,
    TokenResponse,
)
from app.schemas.user import UserRead
from app.services.notification_service import notification_service
from app.services.websocket_manager import manager

router = APIRouter(prefix="/auth", tags=["auth"])


@router.get("/registration/departments", response_model=list[RegistrationDepartment])
def registration_departments(
    db: Annotated[Session, Depends(get_db)],
) -> list[Department]:
    if not settings.self_registration_enabled:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="El registro de usuarios no esta habilitado",
        )
    return list(
        db.scalars(
            select(Department)
            .where(Department.is_active.is_(True))
            .order_by(Department.name.asc())
        ).all()
    )


@router.post(
    "/register",
    response_model=RegistrationResponse,
    status_code=status.HTTP_201_CREATED,
)
async def register(
    payload: RegistrationRequest,
    background_tasks: BackgroundTasks,
    db: Annotated[Session, Depends(get_db)],
) -> RegistrationResponse:
    if not settings.self_registration_enabled:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="El registro de usuarios no esta habilitado",
        )

    email = str(payload.email).lower()
    if db.scalar(select(User.id).where(User.email == email)) is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ya existe una cuenta o solicitud con este correo",
        )

    department = db.get(Department, payload.department_id)
    if department is None or not department.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Seleccione un departamento activo",
        )

    user = User(
        name=payload.name,
        email=email,
        password_hash=hash_password(payload.password),
        is_admin=False,
        is_active=False,
        account_status=ACCOUNT_STATUS_PENDING,
    )
    db.add(user)
    db.flush()
    db.add(
        DepartmentMember(
            department_id=department.id,
            user_id=user.id,
            is_active=True,
        )
    )
    notification_registered = False
    if payload.device_registration is not None:
        now = datetime.now(UTC)
        device_payload = payload.device_registration
        registration = db.scalar(
            select(DeviceRegistration).where(
                DeviceRegistration.registration_id == device_payload.registration_id
            )
        )
        if registration is None:
            registration = DeviceRegistration(
                user_id=user.id,
                registration_id=device_payload.registration_id,
                registration_kind=device_payload.registration_kind,
                platform=device_payload.platform,
                device_name=device_payload.device_name,
                is_active=True,
                created_at=now,
                updated_at=now,
                last_seen_at=now,
            )
        else:
            registration.user_id = user.id
            registration.registration_kind = device_payload.registration_kind
            registration.platform = device_payload.platform
            registration.device_name = device_payload.device_name
            registration.is_active = True
            registration.updated_at = now
            registration.last_seen_at = now
            registration.last_error = None
        db.add(registration)
        notification_registered = True

    try:
        db.commit()
    except IntegrityError as error:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ya existe una cuenta o solicitud con este correo",
        ) from error
    db.refresh(user)

    pending_count = int(
        db.scalar(
            select(func.count(User.id)).where(
                User.account_status == ACCOUNT_STATUS_PENDING
            )
        )
        or 0
    )
    await manager.broadcast_admins(
        {
            "event": "access_request.created",
            "request_id": str(user.id),
            "department_id": str(department.id),
            "pending_count": pending_count,
        }
    )
    background_tasks.add_task(
        notification_service.notify_access_request_created,
        user_id=user.id,
    )

    return RegistrationResponse(
        id=user.id,
        name=user.name,
        email=user.email,
        account_status=user.account_status,
        department_id=department.id,
        notification_registered=notification_registered,
        message="Solicitud enviada. Un administrador debe aprobar tu acceso.",
    )


@router.post("/login", response_model=TokenResponse)
def login(
    payload: LoginRequest, db: Annotated[Session, Depends(get_db)]
) -> TokenResponse:
    user = db.scalar(select(User).where(User.email == payload.email.lower()))
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Correo o contrasena incorrectos",
        )
    if user.account_status == ACCOUNT_STATUS_PENDING:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Tu solicitud esta pendiente de aprobacion por un administrador",
        )
    if user.account_status == ACCOUNT_STATUS_REJECTED:
        message = "Tu solicitud de acceso fue rechazada"
        if user.review_note:
            message = f"{message}: {user.review_note}"
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=message)
    if user.account_status == ACCOUNT_STATUS_SUSPENDED or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Tu cuenta esta suspendida. Contacta al administrador",
        )
    if user.account_status != ACCOUNT_STATUS_APPROVED:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Tu cuenta no esta disponible",
        )

    return TokenResponse(
        access_token=create_access_token(user.id),
        user=UserRead.model_validate(user),
    )


@router.get("/me", response_model=UserRead)
def me(current_user: Annotated[User, Depends(get_current_user)]) -> User:
    return current_user
