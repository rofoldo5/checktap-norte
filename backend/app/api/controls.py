from datetime import UTC, datetime
from typing import Annotated, Literal
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.control import ControlCheck, ControlSection
from app.models.user import User
from app.schemas.control import (
    ControlCheckComplete,
    ControlCheckCreate,
    ControlCheckRead,
    ControlCheckUpdate,
    ControlSectionCreate,
    ControlSectionRead,
    ControlSectionUpdate,
    ControlSnapshot,
)
from app.services.control_permissions import (
    require_control_check_create,
    require_control_check_edit,
    require_control_check_work,
    require_control_section_manage,
    require_control_section_view,
)
from app.services.control_service import (
    check_read,
    complete_control_check,
    configure_control_schedule,
    control_check_query,
    control_due_state,
    control_section_query,
    get_control_check,
    get_control_section,
    reopen_control_check,
    section_read,
    set_control_assignees,
    update_control_check_from_payload,
)
from app.services.department_service import active_department_ids, resolve_task_department
from app.services.websocket_manager import manager

router = APIRouter(prefix="/controls", tags=["controls"])

ControlFilter = Literal["ALL", "UPCOMING", "URGENT", "OVERDUE", "COMPLETED"]


def _visible_sections_query(current_user: User):
    query = control_section_query().where(ControlSection.is_active.is_(True))
    if current_user.is_admin:
        return query
    department_ids = active_department_ids(current_user)
    if not department_ids:
        return query.where(ControlSection.id.is_(None))
    return query.where(ControlSection.department_id.in_(department_ids))


def _matches_filter(check: ControlCheck, filter_value: ControlFilter) -> bool:
    if filter_value == "ALL":
        return True
    state = control_due_state(check)
    if filter_value == "UPCOMING":
        return state in {"PROXIMA", "URGENTE"}
    if filter_value == "URGENT":
        return state == "URGENTE"
    if filter_value == "OVERDUE":
        return state == "VENCIDA"
    return state == "COMPLETADA"


@router.get("/sections", response_model=list[ControlSectionRead])
def list_control_sections(
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
    department_id: UUID | None = Query(default=None),
) -> list[ControlSectionRead]:
    query = _visible_sections_query(current_user)
    if department_id is not None:
        if not current_user.is_admin and department_id not in active_department_ids(current_user):
            raise HTTPException(status_code=403, detail="No pertenece a este departamento")
        query = query.where(ControlSection.department_id == department_id)
    sections = list(db.scalars(query.order_by(ControlSection.name.asc())).unique().all())
    return [section_read(section) for section in sections]


@router.post("/sections", response_model=ControlSectionRead, status_code=status.HTTP_201_CREATED)
async def create_control_section(
    payload: ControlSectionCreate,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> ControlSectionRead:
    require_control_section_manage(current_user)
    department = resolve_task_department(db, current_user, payload.department_id)
    duplicate = db.scalar(
        select(ControlSection).where(
            ControlSection.department_id == department.id,
            ControlSection.name == payload.name,
            ControlSection.is_active.is_(True),
        )
    )
    if duplicate is not None:
        raise HTTPException(status_code=409, detail="Ya existe una seccion con ese nombre")
    section = ControlSection(
        id=payload.id,
        name=payload.name,
        description=payload.description,
        icon_key=payload.icon_key,
        department_id=department.id,
        created_by_id=current_user.id,
        version=1,
    )
    db.add(section)
    db.commit()
    section = get_control_section(db, section.id)
    await manager.broadcast(
        {
            "event": "control.section.created",
            "section_id": str(section.id),
            "department_id": str(section.department_id),
            "version": section.version,
        }
    )
    return section_read(section)


@router.patch("/sections/{section_id}", response_model=ControlSectionRead)
async def update_control_section(
    section_id: UUID,
    payload: ControlSectionUpdate,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> ControlSectionRead:
    section = get_control_section(db, section_id)
    require_control_section_manage(current_user, section)
    values = payload.model_dump(exclude_unset=True)
    if "department_id" in values:
        department = resolve_task_department(db, current_user, values.pop("department_id"))
        section.department_id = department.id
    for key, value in values.items():
        setattr(section, key, value)
    if values or "department_id" in payload.model_fields_set:
        section.version += 1
        section.updated_at = datetime.now(UTC)
    db.add(section)
    db.commit()
    section = get_control_section(db, section_id)
    await manager.broadcast(
        {
            "event": "control.section.updated",
            "section_id": str(section.id),
            "department_id": str(section.department_id),
            "version": section.version,
        }
    )
    return section_read(section)


@router.delete("/sections/{section_id}", response_model=ControlSectionRead)
async def archive_control_section(
    section_id: UUID,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> ControlSectionRead:
    section = get_control_section(db, section_id)
    require_control_section_manage(current_user, section)
    section.is_active = False
    section.version += 1
    section.updated_at = datetime.now(UTC)
    db.add(section)
    db.commit()
    section = get_control_section(db, section_id)
    await manager.broadcast(
        {
            "event": "control.section.archived",
            "section_id": str(section.id),
            "department_id": str(section.department_id),
            "version": section.version,
        }
    )
    return section_read(section)


@router.get("/sections/{section_id}/checks", response_model=list[ControlCheckRead])
def list_control_checks(
    section_id: UUID,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
    state: ControlFilter = Query(default="ALL"),
    q: str | None = Query(default=None, max_length=200),
) -> list[ControlCheckRead]:
    section = get_control_section(db, section_id)
    require_control_section_view(current_user, section)
    checks = list(
        db.scalars(
            control_check_query()
            .where(ControlCheck.section_id == section.id)
            .order_by(ControlCheck.due_at.asc(), ControlCheck.title.asc())
        ).unique().all()
    )
    normalized_query = (q or "").strip().lower()
    result: list[ControlCheckRead] = []
    for check in checks:
        if not _matches_filter(check, state):
            continue
        if normalized_query:
            haystack = " ".join(
                item
                for item in (
                    check.title,
                    check.description or "",
                    check.reference or "",
                    check.contact or "",
                    check.notes or "",
                )
                if item
            ).lower()
            if normalized_query not in haystack:
                continue
        result.append(check_read(check))
    return result


@router.post(
    "/sections/{section_id}/checks",
    response_model=ControlCheckRead,
    status_code=status.HTTP_201_CREATED,
)
async def create_control_check(
    section_id: UUID,
    payload: ControlCheckCreate,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> ControlCheckRead:
    section = get_control_section(db, section_id)
    require_control_check_create(current_user, section)
    check = ControlCheck(
        id=payload.id,
        section_id=section.id,
        title=payload.title,
        description=payload.description,
        reference=payload.reference,
        contact=payload.contact,
        notes=payload.notes,
        priority=payload.priority,
        status="PENDIENTE",
        due_at=payload.due_at,
        timezone=payload.timezone,
        recurrence_type=payload.recurrence_type,
        recurrence_interval=payload.recurrence_interval,
        recurrence_unit=payload.recurrence_unit,
        created_by_id=current_user.id,
        version=1,
    )
    check.section = section
    db.add(check)
    db.flush()
    configure_control_schedule(check, payload)
    set_control_assignees(db, check, payload.assignee_ids)
    db.commit()
    check = get_control_check(db, check.id)
    await manager.broadcast(
        {
            "event": "control.check.created",
            "check_id": str(check.id),
            "section_id": str(check.section_id),
            "department_id": str(check.section.department_id),
            "version": check.version,
        }
    )
    return check_read(check)


@router.get("/checks/{check_id}", response_model=ControlCheckRead)
def read_control_check(
    check_id: UUID,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> ControlCheckRead:
    check = get_control_check(db, check_id)
    require_control_section_view(current_user, check.section)
    return check_read(check)


@router.patch("/checks/{check_id}", response_model=ControlCheckRead)
async def update_control_check(
    check_id: UUID,
    payload: ControlCheckUpdate,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> ControlCheckRead:
    check = get_control_check(db, check_id)
    require_control_check_edit(current_user, check)
    update_control_check_from_payload(db, check, payload)
    db.add(check)
    db.commit()
    check = get_control_check(db, check_id)
    await manager.broadcast(
        {
            "event": "control.check.updated",
            "check_id": str(check.id),
            "section_id": str(check.section_id),
            "department_id": str(check.section.department_id),
            "version": check.version,
        }
    )
    return check_read(check)


@router.post("/checks/{check_id}/complete", response_model=ControlCheckRead)
async def complete_check(
    check_id: UUID,
    payload: ControlCheckComplete,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> ControlCheckRead:
    check = get_control_check(db, check_id)
    require_control_check_work(current_user, check)
    complete_control_check(check, current_user, notes=payload.notes)
    db.add(check)
    db.commit()
    check = get_control_check(db, check_id)
    await manager.broadcast(
        {
            "event": "control.check.completed",
            "check_id": str(check.id),
            "section_id": str(check.section_id),
            "department_id": str(check.section.department_id),
            "version": check.version,
        }
    )
    return check_read(check)


@router.post("/checks/{check_id}/reopen", response_model=ControlCheckRead)
async def reopen_check(
    check_id: UUID,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> ControlCheckRead:
    check = get_control_check(db, check_id)
    require_control_check_work(current_user, check)
    reopen_control_check(check)
    db.add(check)
    db.commit()
    check = get_control_check(db, check_id)
    await manager.broadcast(
        {
            "event": "control.check.reopened",
            "check_id": str(check.id),
            "section_id": str(check.section_id),
            "department_id": str(check.section.department_id),
            "version": check.version,
        }
    )
    return check_read(check)


@router.delete("/checks/{check_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_control_check(
    check_id: UUID,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> None:
    check = get_control_check(db, check_id)
    require_control_check_edit(current_user, check)
    department_id = check.section.department_id
    section_id = check.section_id
    db.delete(check)
    db.commit()
    await manager.broadcast(
        {
            "event": "control.check.deleted",
            "check_id": str(check_id),
            "section_id": str(section_id),
            "department_id": str(department_id),
        }
    )


@router.get("/snapshot", response_model=ControlSnapshot)
def control_snapshot(
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> ControlSnapshot:
    sections = list(
        db.scalars(_visible_sections_query(current_user).order_by(ControlSection.name.asc()))
        .unique()
        .all()
    )
    section_ids = [section.id for section in sections]
    checks: list[ControlCheck] = []
    if section_ids:
        checks = list(
            db.scalars(
                control_check_query()
                .where(ControlCheck.section_id.in_(section_ids))
                .order_by(ControlCheck.due_at.asc(), ControlCheck.title.asc())
            ).unique().all()
        )
    return ControlSnapshot(
        sections=[section_read(section) for section in sections],
        checks=[check_read(check) for check in checks],
    )
