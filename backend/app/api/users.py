from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.core.database import get_db
from app.core.dependencies import get_current_user, require_admin
from app.core.security import hash_password
from app.models.department import DepartmentMember
from app.models.user import User
from app.schemas.user import UserCreate, UserRead, UserSummary, UserUpdate
from app.services.department_service import active_department_ids, replace_user_departments

router = APIRouter(prefix="/users", tags=["users"])


def _user_query():
    return select(User).options(selectinload(User.department_memberships))


@router.get("", response_model=list[UserSummary])
def list_users(
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> list[User]:
    query = _user_query().where(User.is_active.is_(True)).order_by(User.name.asc())
    if not current_user.is_admin:
        department_ids = active_department_ids(current_user)
        query = (
            query.join(DepartmentMember, DepartmentMember.user_id == User.id)
            .where(
                DepartmentMember.department_id.in_(department_ids),
                DepartmentMember.is_active.is_(True),
            )
            .distinct()
        )
    return list(db.scalars(query).unique().all())


@router.get("/manage", response_model=list[UserRead])
def list_users_for_management(
    db: Annotated[Session, Depends(get_db)],
    _: Annotated[User, Depends(require_admin)],
) -> list[User]:
    return list(db.scalars(_user_query().order_by(User.name.asc())).unique().all())


@router.post("", response_model=UserRead, status_code=status.HTTP_201_CREATED)
def create_user(
    payload: UserCreate,
    db: Annotated[Session, Depends(get_db)],
    _: Annotated[User, Depends(require_admin)],
) -> User:
    email = str(payload.email).lower()
    existing = db.scalar(select(User).where(User.email == email))
    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="El correo ya esta registrado",
        )

    user = User(
        name=payload.name,
        email=email,
        password_hash=hash_password(payload.password),
        is_admin=payload.is_admin,
    )
    db.add(user)
    db.flush()
    replace_user_departments(db, user, payload.department_ids)
    db.commit()
    db.refresh(user)
    return user


@router.patch("/{user_id}", response_model=UserRead)
def update_user(
    user_id: UUID,
    payload: UserUpdate,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(require_admin)],
) -> User:
    user = db.scalar(_user_query().where(User.id == user_id))
    if user is None:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")

    values = payload.model_dump(exclude_unset=True)
    if not values:
        return user

    if user.id == current_user.id:
        if values.get("is_active") is False:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No puede desactivar su propia cuenta",
            )
        if values.get("is_admin") is False:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No puede retirar sus propios permisos de administrador",
            )

    department_ids = values.pop("department_ids", None)
    if "password" in values:
        user.password_hash = hash_password(values.pop("password"))

    for field, value in values.items():
        setattr(user, field, value)

    if department_ids is not None:
        replace_user_departments(db, user, department_ids)

    db.add(user)
    db.commit()
    db.refresh(user)
    return user
