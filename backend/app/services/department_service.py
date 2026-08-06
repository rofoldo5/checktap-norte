from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.department import Department, DepartmentMember
from app.models.user import User


def get_default_department(db: Session, *, create: bool = True) -> Department | None:
    department = db.scalar(
        select(Department).where(Department.name == settings.default_department_name)
    )
    if department is None and create:
        department = Department(name=settings.default_department_name, is_active=True)
        db.add(department)
        db.flush()
    return department


def active_department_ids(user: User) -> list[UUID]:
    return [
        membership.department_id
        for membership in user.department_memberships
        if membership.is_active and membership.department.is_active
    ]


def is_department_member(user: User, department_id: UUID) -> bool:
    return user.is_admin or department_id in active_department_ids(user)


def require_department_access(user: User, department_id: UUID) -> None:
    if not is_department_member(user, department_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No pertenece al departamento de esta tarea",
        )


def resolve_task_department(
    db: Session,
    user: User,
    requested_department_id: UUID | None,
) -> Department:
    if requested_department_id is not None:
        department = db.get(Department, requested_department_id)
        if department is None or not department.is_active:
            raise HTTPException(status_code=400, detail="Departamento no valido")
        require_department_access(user, department.id)
        return department

    memberships = [
        membership
        for membership in user.department_memberships
        if membership.is_active and membership.department.is_active
    ]
    if len(memberships) == 1:
        return memberships[0].department

    default_department = get_default_department(db)
    if default_department is not None and (
        user.is_admin
        or any(item.department_id == default_department.id for item in memberships)
    ):
        return default_department

    if memberships:
        return sorted(memberships, key=lambda item: item.department.name)[0].department

    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail="El usuario no pertenece a ningun departamento activo",
    )


def validate_department_users(
    db: Session,
    department_id: UUID,
    user_ids: list[UUID],
) -> list[User]:
    if not user_ids:
        return []

    unique_ids = list(dict.fromkeys(user_ids))
    users = list(
        db.scalars(
            select(User).where(User.id.in_(unique_ids), User.is_active.is_(True))
        ).all()
    )
    if len(users) != len(unique_ids):
        raise HTTPException(status_code=400, detail="Uno o mas responsables no son validos")

    membership_user_ids = set(
        db.scalars(
            select(DepartmentMember.user_id).where(
                DepartmentMember.department_id == department_id,
                DepartmentMember.user_id.in_(unique_ids),
                DepartmentMember.is_active.is_(True),
            )
        ).all()
    )
    if membership_user_ids != set(unique_ids):
        raise HTTPException(
            status_code=400,
            detail="Todos los responsables deben pertenecer al departamento",
        )
    users_by_id = {user.id: user for user in users}
    return [users_by_id[user_id] for user_id in unique_ids]


def replace_user_departments(
    db: Session,
    user: User,
    department_ids: list[UUID],
) -> None:
    normalized_ids = list(dict.fromkeys(department_ids))
    if not normalized_ids:
        default = get_default_department(db)
        assert default is not None
        normalized_ids = [default.id]

    departments = list(
        db.scalars(
            select(Department).where(
                Department.id.in_(normalized_ids),
                Department.is_active.is_(True),
            )
        ).all()
    )
    if len(departments) != len(normalized_ids):
        raise HTTPException(status_code=400, detail="Departamento no valido")

    memberships_by_department = {
        membership.department_id: membership
        for membership in user.department_memberships
    }
    now = datetime.now(UTC)
    requested = set(normalized_ids)

    for membership in user.department_memberships:
        membership.is_active = membership.department_id in requested
        membership.updated_at = now

    for department_id in normalized_ids:
        membership = memberships_by_department.get(department_id)
        if membership is None:
            db.add(
                DepartmentMember(
                    department_id=department_id,
                    user_id=user.id,
                    is_active=True,
                )
            )
        else:
            membership.is_active = True
            membership.updated_at = now


def ensure_default_memberships(db: Session) -> Department:
    department = get_default_department(db)
    assert department is not None
    users = list(db.scalars(select(User)).all())
    for user in users:
        if any(
            membership.is_active and membership.department.is_active
            for membership in user.department_memberships
        ):
            continue
        db.add(
            DepartmentMember(
                department_id=department.id,
                user_id=user.id,
                is_active=True,
            )
        )
    return department
