from __future__ import annotations

import calendar
from datetime import UTC, datetime, timedelta
from uuid import UUID
from zoneinfo import ZoneInfo

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload, selectinload

from app.models.control import (
    ControlCheck,
    ControlCheckHistory,
    ControlCheckReminder,
    ControlSection,
)
from app.models.user import User
from app.schemas.control import (
    ControlCheckCreate,
    ControlCheckRead,
    ControlCheckUpdate,
    ControlSectionRead,
)
from app.services.department_service import validate_department_users


CONTROL_NONE = "NONE"
CONTROL_DAILY = "DAILY"
CONTROL_WEEKLY = "WEEKLY"
CONTROL_MONTHLY = "MONTHLY"
CONTROL_YEARLY = "YEARLY"
CONTROL_CUSTOM = "CUSTOM"

UNIT_DAYS = "DAYS"
UNIT_WEEKS = "WEEKS"
UNIT_MONTHS = "MONTHS"
UNIT_YEARS = "YEARS"


def _aware_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)


def _days_in_month(year: int, month: int) -> int:
    return calendar.monthrange(year, month)[1]


def _add_months_local(value: datetime, months: int, *, anchor_day: int) -> datetime:
    total = value.year * 12 + (value.month - 1) + months
    year = total // 12
    month = total % 12 + 1
    day = min(anchor_day, _days_in_month(year, month))
    return value.replace(year=year, month=month, day=day)


def _add_years_local(
    value: datetime,
    years: int,
    *,
    anchor_month: int,
    anchor_day: int,
) -> datetime:
    year = value.year + years
    month = anchor_month
    day = min(anchor_day, _days_in_month(year, month))
    return value.replace(year=year, month=month, day=day)


def next_control_due_at(check: ControlCheck) -> datetime | None:
    if check.recurrence_type == CONTROL_NONE:
        return None

    location = ZoneInfo(check.timezone)
    current_local = _aware_utc(check.due_at).astimezone(location)
    anchor_day = check.recurrence_anchor_day or current_local.day
    anchor_month = check.recurrence_anchor_month or current_local.month

    if check.recurrence_type == CONTROL_DAILY:
        next_local = current_local + timedelta(days=1)
    elif check.recurrence_type == CONTROL_WEEKLY:
        next_local = current_local + timedelta(days=7)
    elif check.recurrence_type == CONTROL_MONTHLY:
        next_local = _add_months_local(current_local, 1, anchor_day=anchor_day)
    elif check.recurrence_type == CONTROL_YEARLY:
        next_local = _add_years_local(
            current_local,
            1,
            anchor_month=anchor_month,
            anchor_day=anchor_day,
        )
    elif check.recurrence_type == CONTROL_CUSTOM:
        interval = max(check.recurrence_interval, 1)
        if check.recurrence_unit == UNIT_WEEKS:
            next_local = current_local + timedelta(weeks=interval)
        elif check.recurrence_unit == UNIT_MONTHS:
            next_local = _add_months_local(
                current_local,
                interval,
                anchor_day=anchor_day,
            )
        elif check.recurrence_unit == UNIT_YEARS:
            next_local = _add_years_local(
                current_local,
                interval,
                anchor_month=anchor_month,
                anchor_day=anchor_day,
            )
        else:
            next_local = current_local + timedelta(days=interval)
    else:
        return None

    return next_local.astimezone(UTC)


def control_due_state(check: ControlCheck, *, now_utc: datetime | None = None) -> str:
    if check.status == "COMPLETADA":
        return "COMPLETADA"
    now = _aware_utc(now_utc or datetime.now(UTC))
    due = _aware_utc(check.due_at)
    if due < now:
        return "VENCIDA"
    remaining = due - now
    if remaining <= timedelta(days=7):
        return "URGENTE"
    if remaining <= timedelta(days=30):
        return "PROXIMA"
    return "VIGENTE"


def next_control_reminder_at(
    check: ControlCheck,
    *,
    now_utc: datetime | None = None,
) -> datetime | None:
    if check.status == "COMPLETADA":
        return None
    now = _aware_utc(now_utc or datetime.now(UTC))
    due = _aware_utc(check.due_at)
    candidates = sorted(
        (
            due - timedelta(minutes=reminder.minutes_before)
            for reminder in check.reminders
        )
    )
    for candidate in candidates:
        if candidate > now:
            return candidate
    return None


def control_section_query():
    return select(ControlSection).options(
        joinedload(ControlSection.department),
        joinedload(ControlSection.created_by).selectinload(User.department_memberships),
        selectinload(ControlSection.checks).selectinload(ControlCheck.reminders),
    )


def control_check_query():
    return select(ControlCheck).options(
        joinedload(ControlCheck.section).joinedload(ControlSection.department),
        joinedload(ControlCheck.created_by).selectinload(User.department_memberships),
        joinedload(ControlCheck.completed_by).selectinload(User.department_memberships),
        selectinload(ControlCheck.assignees).selectinload(User.department_memberships),
        selectinload(ControlCheck.reminders),
        selectinload(ControlCheck.history).joinedload(ControlCheckHistory.completed_by),
    )


def get_control_section(db: Session, section_id: UUID) -> ControlSection:
    section = db.scalar(control_section_query().where(ControlSection.id == section_id))
    if section is None:
        raise HTTPException(status_code=404, detail="Seccion de control no encontrada")
    return section


def get_control_check(db: Session, check_id: UUID) -> ControlCheck:
    check = db.scalar(control_check_query().where(ControlCheck.id == check_id))
    if check is None:
        raise HTTPException(status_code=404, detail="Control no encontrado")
    return check


def _section_counts(section: ControlSection, *, now_utc: datetime | None = None) -> dict[str, int]:
    counts = {
        "check_count": 0,
        "upcoming_count": 0,
        "urgent_count": 0,
        "overdue_count": 0,
        "completed_count": 0,
    }
    for check in section.checks:
        counts["check_count"] += 1
        state = control_due_state(check, now_utc=now_utc)
        if state == "COMPLETADA":
            counts["completed_count"] += 1
        elif state == "VENCIDA":
            counts["overdue_count"] += 1
        elif state == "URGENTE":
            counts["urgent_count"] += 1
            counts["upcoming_count"] += 1
        elif state == "PROXIMA":
            counts["upcoming_count"] += 1
    return counts


def section_read(section: ControlSection, *, now_utc: datetime | None = None) -> ControlSectionRead:
    return ControlSectionRead.model_validate(
        {
            "id": section.id,
            "name": section.name,
            "description": section.description,
            "icon_key": section.icon_key,
            "department": section.department,
            "created_by": section.created_by,
            "is_active": section.is_active,
            "version": section.version,
            "created_at": section.created_at,
            "updated_at": section.updated_at,
            **_section_counts(section, now_utc=now_utc),
        }
    )


def check_read(check: ControlCheck, *, now_utc: datetime | None = None) -> ControlCheckRead:
    return ControlCheckRead.model_validate(
        {
            "id": check.id,
            "section_id": check.section_id,
            "section_name": check.section.name,
            "title": check.title,
            "description": check.description,
            "reference": check.reference,
            "contact": check.contact,
            "notes": check.notes,
            "priority": check.priority,
            "status": check.status,
            "due_state": control_due_state(check, now_utc=now_utc),
            "due_at": check.due_at,
            "timezone": check.timezone,
            "reminder_minutes": [item.minutes_before for item in check.reminders],
            "next_reminder_at": next_control_reminder_at(check, now_utc=now_utc),
            "recurrence_type": check.recurrence_type,
            "recurrence_interval": check.recurrence_interval,
            "recurrence_unit": check.recurrence_unit,
            "version": check.version,
            "created_by": check.created_by,
            "assignees": check.assignees,
            "completed_by": check.completed_by,
            "completed_at": check.completed_at,
            "created_at": check.created_at,
            "updated_at": check.updated_at,
            "history": check.history,
        }
    )


def set_control_assignees(
    db: Session,
    check: ControlCheck,
    user_ids: list[UUID],
) -> None:
    users = validate_department_users(db, check.section.department_id, user_ids)
    check.assignees = users


def set_control_reminders(check: ControlCheck, minutes: list[int]) -> None:
    check.reminders = [
        ControlCheckReminder(minutes_before=value)
        for value in sorted(set(minutes), reverse=True)
    ]


def configure_control_schedule(check: ControlCheck, payload: ControlCheckCreate) -> None:
    check.due_at = _aware_utc(payload.due_at)
    check.timezone = payload.timezone
    check.recurrence_type = payload.recurrence_type
    check.recurrence_interval = payload.recurrence_interval
    check.recurrence_unit = payload.recurrence_unit
    local_due = check.due_at.astimezone(ZoneInfo(check.timezone))
    check.recurrence_anchor_day = local_due.day
    check.recurrence_anchor_month = local_due.month
    set_control_reminders(check, payload.reminder_minutes)


def update_control_check_from_payload(
    db: Session,
    check: ControlCheck,
    payload: ControlCheckUpdate,
) -> bool:
    values = payload.model_dump(exclude_unset=True)
    assignee_ids = values.pop("assignee_ids", None)
    reminder_minutes = values.pop("reminder_minutes", None)
    schedule_changed = any(
        key in values
        for key in (
            "due_at",
            "timezone",
            "recurrence_type",
            "recurrence_interval",
            "recurrence_unit",
        )
    )
    changed = bool(values) or assignee_ids is not None or reminder_minutes is not None

    for key, value in values.items():
        if key == "due_at":
            value = _aware_utc(value)
        setattr(check, key, value)

    if schedule_changed:
        if check.recurrence_type == CONTROL_NONE:
            check.recurrence_interval = 1
            check.recurrence_unit = None
        elif check.recurrence_type == CONTROL_CUSTOM:
            if check.recurrence_unit is None:
                raise HTTPException(status_code=422, detail="Seleccione la unidad personalizada")
        else:
            check.recurrence_interval = 1
            check.recurrence_unit = None
        local_due = _aware_utc(check.due_at).astimezone(ZoneInfo(check.timezone))
        check.recurrence_anchor_day = local_due.day
        check.recurrence_anchor_month = local_due.month

    if reminder_minutes is not None:
        set_control_reminders(check, reminder_minutes)
    if assignee_ids is not None:
        set_control_assignees(db, check, assignee_ids)

    if changed:
        check.version += 1
        check.updated_at = datetime.now(UTC)
    return changed


def complete_control_check(
    check: ControlCheck,
    current_user: User,
    *,
    notes: str | None = None,
    now_utc: datetime | None = None,
) -> None:
    if check.status == "COMPLETADA":
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="El control ya esta completado")

    now = _aware_utc(now_utc or datetime.now(UTC))
    previous_due = _aware_utc(check.due_at)
    next_due = next_control_due_at(check)
    check.history.append(
        ControlCheckHistory(
            completed_by_id=current_user.id,
            due_at=previous_due,
            completed_at=now,
            next_due_at=next_due,
            completion_notes=notes,
        )
    )
    check.completed_by_id = current_user.id
    check.completed_at = now
    check.version += 1
    check.updated_at = now

    if next_due is None:
        check.status = "COMPLETADA"
    else:
        check.due_at = next_due
        check.status = "PENDIENTE"
        # Se conserva completed_at/by como evidencia de la ultima ejecucion.


def reopen_control_check(check: ControlCheck) -> None:
    if check.recurrence_type != CONTROL_NONE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Los controles recurrentes se reprograman al completarse y no requieren reapertura",
        )
    if check.status != "COMPLETADA":
        return
    check.status = "PENDIENTE"
    check.completed_by_id = None
    check.completed_at = None
    check.version += 1
    check.updated_at = datetime.now(UTC)
