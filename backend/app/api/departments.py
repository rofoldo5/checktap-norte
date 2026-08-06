from datetime import UTC, datetime
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session, selectinload

from app.core.database import get_db
from app.core.dependencies import get_current_user, require_admin
from app.models.department import Department, DepartmentMember
from app.models.user import User
from app.schemas.department import (
    DepartmentCreate,
    DepartmentMembersUpdate,
    DepartmentRead,
    DepartmentSummary,
    DepartmentUpdate,
)
from app.schemas.user import UserSummary
from app.services.department_service import active_department_ids, require_department_access

router = APIRouter(prefix="/departments", tags=["departments"])


def _summary(db: Session, department: Department) -> DepartmentSummary:
    member_count = db.scalar(
        select(func.count(DepartmentMember.id)).where(
            DepartmentMember.department_id == department.id,
            DepartmentMember.is_active.is_(True),
        )
    )
    return DepartmentSummary(
        id=department.id,
        name=department.name,
        is_active=department.is_active,
        member_count=int(member_count or 0),
    )


def _read(db: Session, department: Department) -> DepartmentRead:
    members = list(
        db.scalars(
            select(User)
            .join(DepartmentMember, DepartmentMember.user_id == User.id)
            .where(
                DepartmentMember.department_id == department.id,
                DepartmentMember.is_active.is_(True),
                User.is_active.is_(True),
            )
            .options(selectinload(User.department_memberships))
            .order_by(User.name.asc())
        ).unique().all()
    )
    summary = _summary(db, department)
    return DepartmentRead(
        **summary.model_dump(),
        members=[UserSummary.model_validate(user) for user in members],
        created_at=department.created_at,
        updated_at=department.updated_at,
    )


@router.get("", response_model=list[DepartmentSummary])
def list_departments(
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> list[DepartmentSummary]:
    query = select(Department).order_by(Department.name.asc())
    if not current_user.is_admin:
        department_ids = active_department_ids(current_user)
        query = query.where(
            Department.id.in_(department_ids),
            Department.is_active.is_(True),
        )
    departments = list(db.scalars(query).all())
    return [_summary(db, department) for department in departments]


@router.get("/{department_id}", response_model=DepartmentRead)
def get_department(
    department_id: UUID,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> DepartmentRead:
    department = db.get(Department, department_id)
    if department is None:
        raise HTTPException(status_code=404, detail="Departamento no encontrado")
    require_department_access(current_user, department.id)
    return _read(db, department)


@router.post("", response_model=DepartmentRead, status_code=status.HTTP_201_CREATED)
def create_department(
    payload: DepartmentCreate,
    db: Annotated[Session, Depends(get_db)],
    _: Annotated[User, Depends(require_admin)],
) -> DepartmentRead:
    existing = db.scalar(select(Department).where(Department.name == payload.name))
    if existing is not None:
        raise HTTPException(status_code=409, detail="El departamento ya existe")
    department = Department(name=payload.name, is_active=True)
    db.add(department)
    db.commit()
    db.refresh(department)
    return _read(db, department)


@router.patch("/{department_id}", response_model=DepartmentRead)
def update_department(
    department_id: UUID,
    payload: DepartmentUpdate,
    db: Annotated[Session, Depends(get_db)],
    _: Annotated[User, Depends(require_admin)],
) -> DepartmentRead:
    department = db.get(Department, department_id)
    if department is None:
        raise HTTPException(status_code=404, detail="Departamento no encontrado")
    values = payload.model_dump(exclude_unset=True)
    if "name" in values:
        duplicate = db.scalar(
            select(Department).where(
                Department.name == values["name"],
                Department.id != department.id,
            )
        )
        if duplicate is not None:
            raise HTTPException(status_code=409, detail="El departamento ya existe")
    for field, value in values.items():
        setattr(department, field, value)
    department.updated_at = datetime.now(UTC)
    db.add(department)
    db.commit()
    db.refresh(department)
    return _read(db, department)


@router.put("/{department_id}/members", response_model=DepartmentRead)
def replace_department_members(
    department_id: UUID,
    payload: DepartmentMembersUpdate,
    db: Annotated[Session, Depends(get_db)],
    _: Annotated[User, Depends(require_admin)],
) -> DepartmentRead:
    department = db.get(Department, department_id)
    if department is None:
        raise HTTPException(status_code=404, detail="Departamento no encontrado")

    requested_ids = list(dict.fromkeys(payload.user_ids))
    users = list(
        db.scalars(select(User).where(User.id.in_(requested_ids))).all()
    ) if requested_ids else []
    if len(users) != len(requested_ids):
        raise HTTPException(status_code=400, detail="Uno o mas usuarios no existen")

    existing = {
        membership.user_id: membership
        for membership in db.scalars(
            select(DepartmentMember).where(
                DepartmentMember.department_id == department.id
            )
        ).all()
    }
    requested = set(requested_ids)
    now = datetime.now(UTC)
    for membership in existing.values():
        membership.is_active = membership.user_id in requested
        membership.updated_at = now
    for user_id in requested_ids:
        membership = existing.get(user_id)
        if membership is None:
            db.add(
                DepartmentMember(
                    department_id=department.id,
                    user_id=user_id,
                    is_active=True,
                )
            )
        else:
            membership.is_active = True
            membership.updated_at = now
    db.commit()
    db.refresh(department)
    return _read(db, department)
