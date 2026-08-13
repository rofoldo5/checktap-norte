from __future__ import annotations

import calendar
from datetime import UTC, datetime, timedelta
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.models.checklist import TaskChecklist, TaskChecklistItem
from app.models.task import Task

RECURRENCE_NONE = "NONE"
RECURRENCE_DAILY = "DAILY"
RECURRENCE_WEEKLY = "WEEKLY"
RECURRENCE_MONTHLY = "MONTHLY"
RECURRENCE_CUSTOM = "CUSTOM"

UNIT_DAYS = "DAYS"
UNIT_WEEKS = "WEEKS"
UNIT_MONTHS = "MONTHS"

RECURRENCE_TYPES = {
    RECURRENCE_NONE,
    RECURRENCE_DAILY,
    RECURRENCE_WEEKLY,
    RECURRENCE_MONTHLY,
    RECURRENCE_CUSTOM,
}
RECURRENCE_UNITS = {UNIT_DAYS, UNIT_WEEKS, UNIT_MONTHS}


def _aware_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)


def validate_timezone(name: str) -> str:
    normalized = (name or "UTC").strip() or "UTC"
    try:
        ZoneInfo(normalized)
    except ZoneInfoNotFoundError as exc:
        raise ValueError("La zona horaria no es valida") from exc
    return normalized


def _add_months_local(value: datetime, months: int, anchor_day: int) -> datetime:
    total_month = value.year * 12 + (value.month - 1) + months
    year, month_index = divmod(total_month, 12)
    month = month_index + 1
    day = min(anchor_day, calendar.monthrange(year, month)[1])
    return value.replace(year=year, month=month, day=day)


def next_occurrence(
    current_utc: datetime,
    *,
    recurrence_type: str,
    interval: int = 1,
    unit: str | None = None,
    timezone_name: str = "UTC",
    anchor_utc: datetime | None = None,
) -> datetime:
    recurrence_type = recurrence_type.upper()
    if recurrence_type not in RECURRENCE_TYPES - {RECURRENCE_NONE}:
        raise ValueError("Tipo de recurrencia no soportado")
    if interval < 1:
        raise ValueError("El intervalo de recurrencia debe ser mayor que cero")

    location = ZoneInfo(validate_timezone(timezone_name))
    current_local = _aware_utc(current_utc).astimezone(location)
    anchor_local = _aware_utc(anchor_utc or current_utc).astimezone(location)

    if recurrence_type == RECURRENCE_DAILY:
        days = 1
        next_local = datetime(
            current_local.year,
            current_local.month,
            current_local.day,
            current_local.hour,
            current_local.minute,
            current_local.second,
            tzinfo=location,
        ) + timedelta(days=days)
    elif recurrence_type == RECURRENCE_WEEKLY:
        next_local = datetime(
            current_local.year,
            current_local.month,
            current_local.day,
            current_local.hour,
            current_local.minute,
            current_local.second,
            tzinfo=location,
        ) + timedelta(days=7)
    elif recurrence_type == RECURRENCE_MONTHLY:
        next_local = _add_months_local(current_local, 1, anchor_local.day)
    else:
        normalized_unit = (unit or "").upper()
        if normalized_unit not in RECURRENCE_UNITS:
            raise ValueError("Seleccione la unidad de la recurrencia personalizada")
        if normalized_unit == UNIT_DAYS:
            next_local = current_local + timedelta(days=interval)
        elif normalized_unit == UNIT_WEEKS:
            next_local = current_local + timedelta(days=7 * interval)
        else:
            next_local = _add_months_local(current_local, interval, anchor_local.day)

    return next_local.astimezone(UTC)


def first_future_occurrence(
    start_utc: datetime,
    *,
    recurrence_type: str,
    interval: int,
    unit: str | None,
    timezone_name: str,
    now_utc: datetime | None = None,
) -> datetime:
    """Return the first recurrence strictly after both start and now.

    The source task itself represents the occurrence at ``start_utc``. This
    method calculates the next child occurrence. Missed historical occurrences
    are skipped when a recurrence is created or edited with a past start date,
    preventing a burst of retroactive tasks.
    """

    now = _aware_utc(now_utc or datetime.now(UTC))
    current = _aware_utc(start_utc)
    candidate = next_occurrence(
        current,
        recurrence_type=recurrence_type,
        interval=interval,
        unit=unit,
        timezone_name=timezone_name,
        anchor_utc=start_utc,
    )
    for _ in range(10000):
        if candidate > now:
            return candidate
        current = candidate
        candidate = next_occurrence(
            current,
            recurrence_type=recurrence_type,
            interval=interval,
            unit=unit,
            timezone_name=timezone_name,
            anchor_utc=start_utc,
        )
    raise ValueError("No fue posible calcular la proxima ejecucion de la tarea")


def configure_recurrence(
    task: Task,
    *,
    recurrence_type: str,
    recurrence_interval: int = 1,
    recurrence_unit: str | None = None,
    recurrence_start_at: datetime | None = None,
    recurrence_timezone: str = "UTC",
    notifications_enabled: bool = False,
    reminder_minutes_before: int = 0,
    now_utc: datetime | None = None,
) -> None:
    recurrence_type = recurrence_type.upper()
    if recurrence_type not in RECURRENCE_TYPES:
        raise ValueError("Tipo de recurrencia no soportado")

    if recurrence_type == RECURRENCE_NONE:
        task.recurrence_type = RECURRENCE_NONE
        task.recurrence_interval = 1
        task.recurrence_unit = None
        task.recurrence_start_at = None
        task.recurrence_timezone = validate_timezone(recurrence_timezone)
        task.next_occurrence_at = None
        task.notifications_enabled = False
        task.reminder_minutes_before = 0
        task.recurrence_series_id = None
        task.is_recurrence_master = False
        task.scheduled_for = None
        return

    if recurrence_start_at is None:
        raise ValueError("Seleccione la fecha y hora de inicio")
    if recurrence_interval < 1 or recurrence_interval > 365:
        raise ValueError("El intervalo debe estar entre 1 y 365")

    recurrence_timezone = validate_timezone(recurrence_timezone)
    recurrence_unit = recurrence_unit.upper() if recurrence_unit else None
    if recurrence_type == RECURRENCE_CUSTOM:
        if recurrence_unit not in RECURRENCE_UNITS:
            raise ValueError("Seleccione dias, semanas o meses")
    else:
        recurrence_interval = 1
        recurrence_unit = None

    if reminder_minutes_before < 0 or reminder_minutes_before > 10080:
        raise ValueError("El recordatorio previo no es valido")

    start = _aware_utc(recurrence_start_at)
    task.recurrence_type = recurrence_type
    task.recurrence_interval = recurrence_interval
    task.recurrence_unit = recurrence_unit
    task.recurrence_start_at = start
    task.recurrence_timezone = recurrence_timezone
    task.notifications_enabled = notifications_enabled
    task.reminder_minutes_before = reminder_minutes_before
    task.is_recurrence_master = True
    task.recurrence_series_id = str(task.id)
    task.scheduled_for = start
    task.next_occurrence_at = first_future_occurrence(
        start,
        recurrence_type=recurrence_type,
        interval=recurrence_interval,
        unit=recurrence_unit,
        timezone_name=recurrence_timezone,
        now_utc=now_utc,
    )


RECURRENCE_EDIT_FIELDS = {
    "recurrence_type",
    "recurrence_interval",
    "recurrence_unit",
    "recurrence_start_at",
    "recurrence_timezone",
    "notifications_enabled",
    "reminder_minutes_before",
}


def pop_recurrence_changes(values: dict[str, object]) -> dict[str, object]:
    changes: dict[str, object] = {}
    for field in RECURRENCE_EDIT_FIELDS:
        if field in values:
            changes[field] = values.pop(field)
    return changes


def configure_recurrence_from_changes(
    task: Task,
    changes: dict[str, object],
    *,
    now_utc: datetime | None = None,
) -> bool:
    """Apply a partial recurrence update to an existing task.

    Generated occurrences intentionally inherit the schedule read-only. Their
    title, priority and assignees may still be edited independently, while the
    recurrence itself is managed from the original/master task.
    """

    if not changes:
        return False
    if task.recurrence_type != RECURRENCE_NONE and not task.is_recurrence_master:
        raise ValueError(
            "La programacion se modifica desde la tarea original de la serie"
        )

    recurrence_type = str(
        changes.get("recurrence_type", task.recurrence_type or RECURRENCE_NONE)
    ).upper()
    recurrence_interval = int(
        changes.get("recurrence_interval", task.recurrence_interval or 1)
    )
    raw_unit = changes.get("recurrence_unit", task.recurrence_unit)
    recurrence_unit = str(raw_unit).upper() if raw_unit is not None else None
    start_at = changes.get(
        "recurrence_start_at",
        task.recurrence_start_at or task.scheduled_for,
    )
    timezone_name = str(
        changes.get("recurrence_timezone", task.recurrence_timezone or "UTC")
    )
    notifications_enabled = bool(
        changes.get("notifications_enabled", task.notifications_enabled)
    )
    reminder_minutes_before = int(
        changes.get("reminder_minutes_before", task.reminder_minutes_before or 0)
    )

    configure_recurrence(
        task,
        recurrence_type=recurrence_type,
        recurrence_interval=recurrence_interval,
        recurrence_unit=recurrence_unit,
        recurrence_start_at=start_at if isinstance(start_at, datetime) else None,
        recurrence_timezone=timezone_name,
        notifications_enabled=notifications_enabled,
        reminder_minutes_before=reminder_minutes_before,
        now_utc=now_utc,
    )
    return True


def _clone_task_occurrence(db: Session, master: Task, scheduled_for: datetime) -> Task:
    occurrence = Task(
        title=master.title,
        description=master.description,
        status="PENDIENTE",
        priority=master.priority,
        version=1,
        department_id=master.department_id,
        created_by_id=master.created_by_id,
        assigned_to_id=master.assigned_to_id,
        recurrence_type=master.recurrence_type,
        recurrence_interval=master.recurrence_interval,
        recurrence_unit=master.recurrence_unit,
        recurrence_start_at=master.recurrence_start_at,
        recurrence_timezone=master.recurrence_timezone,
        next_occurrence_at=None,
        notifications_enabled=master.notifications_enabled,
        reminder_minutes_before=master.reminder_minutes_before,
        recurrence_series_id=master.recurrence_series_id or str(master.id),
        is_recurrence_master=False,
        scheduled_for=scheduled_for,
    )
    db.add(occurrence)
    db.flush()
    occurrence.assignees = list(master.assignees)
    occurrence.assigned_to_id = (
        occurrence.assignees[0].id if occurrence.assignees else None
    )

    for checklist in master.checklists:
        cloned_checklist = TaskChecklist(
            task_id=occurrence.id,
            title=checklist.title,
            position=checklist.position,
            version=1,
            created_by_id=checklist.created_by_id,
        )
        db.add(cloned_checklist)
        db.flush()
        for item in checklist.items:
            db.add(
                TaskChecklistItem(
                    checklist_id=cloned_checklist.id,
                    title=item.title,
                    position=item.position,
                    is_completed=False,
                    version=1,
                    created_by_id=item.created_by_id,
                    completed_by_id=None,
                    completed_at=None,
                )
            )
    db.flush()
    return occurrence


def generate_due_occurrences(
    db: Session,
    *,
    now_utc: datetime | None = None,
    max_per_series: int = 100,
) -> list[Task]:
    now = _aware_utc(now_utc or datetime.now(UTC))
    masters = list(
        db.scalars(
            select(Task)
            .where(
                Task.is_recurrence_master.is_(True),
                Task.recurrence_type != RECURRENCE_NONE,
                Task.next_occurrence_at.is_not(None),
                Task.next_occurrence_at <= now,
            )
            .options(
                selectinload(Task.assignees),
                selectinload(Task.checklists).selectinload(TaskChecklist.items),
            )
            .order_by(Task.next_occurrence_at.asc())
        )
        .unique()
        .all()
    )

    generated: list[Task] = []
    for master in masters:
        due = master.next_occurrence_at
        count = 0
        while due is not None and _aware_utc(due) <= now and count < max_per_series:
            due = _aware_utc(due)
            generated.append(_clone_task_occurrence(db, master, due))
            master.next_occurrence_at = next_occurrence(
                due,
                recurrence_type=master.recurrence_type,
                interval=master.recurrence_interval,
                unit=master.recurrence_unit,
                timezone_name=master.recurrence_timezone,
                anchor_utc=master.recurrence_start_at or master.scheduled_for or due,
            )
            due = master.next_occurrence_at
            count += 1
        db.add(master)

    if generated:
        db.commit()
    return generated
