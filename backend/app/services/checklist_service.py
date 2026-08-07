from datetime import UTC, datetime
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.checklist import TaskChecklist, TaskChecklistItem
from app.models.task import Task
from app.models.user import User
from app.schemas.checklist import (
    ChecklistCreate,
    ChecklistItemCreate,
    ChecklistItemUpdate,
    ChecklistUpdate,
)


def ensure_task_open(task: Task) -> None:
    if task.status == "COMPLETADA":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Reabra la tarea antes de modificar sus checklists",
        )


def get_checklist_or_404(
    db: Session,
    task: Task,
    checklist_id: UUID,
) -> TaskChecklist:
    checklist = db.scalar(
        select(TaskChecklist).where(
            TaskChecklist.id == checklist_id,
            TaskChecklist.task_id == task.id,
        )
    )
    if checklist is None:
        raise HTTPException(status_code=404, detail="Checklist no encontrado")
    return checklist


def get_item_or_404(
    db: Session,
    checklist: TaskChecklist,
    item_id: UUID,
) -> TaskChecklistItem:
    item = db.scalar(
        select(TaskChecklistItem).where(
            TaskChecklistItem.id == item_id,
            TaskChecklistItem.checklist_id == checklist.id,
        )
    )
    if item is None:
        raise HTTPException(status_code=404, detail="Actividad no encontrada")
    return item


def _next_checklist_position(db: Session, task_id: UUID) -> int:
    current = db.scalar(
        select(func.max(TaskChecklist.position)).where(TaskChecklist.task_id == task_id)
    )
    return int(current or -1) + 1


def _next_item_position(db: Session, checklist_id: UUID) -> int:
    current = db.scalar(
        select(func.max(TaskChecklistItem.position)).where(
            TaskChecklistItem.checklist_id == checklist_id
        )
    )
    return int(current or -1) + 1


def touch_task(task: Task) -> None:
    task.version += 1
    task.updated_at = datetime.now(UTC)


def create_checklist(
    db: Session,
    task: Task,
    actor: User,
    payload: ChecklistCreate,
) -> TaskChecklist:
    ensure_task_open(task)
    if payload.id is not None and db.get(TaskChecklist, payload.id) is not None:
        raise HTTPException(status_code=409, detail="El checklist ya existe")

    checklist = TaskChecklist(
        id=payload.id,
        task_id=task.id,
        title=payload.title,
        position=payload.position
        if payload.position is not None
        else _next_checklist_position(db, task.id),
        created_by_id=actor.id,
        version=1,
    )
    db.add(checklist)
    db.flush()

    next_position = 0
    for seed in payload.items:
        if seed.id is not None and db.get(TaskChecklistItem, seed.id) is not None:
            raise HTTPException(status_code=409, detail="La actividad ya existe")
        position = seed.position if seed.position is not None else next_position
        db.add(
            TaskChecklistItem(
                id=seed.id,
                checklist_id=checklist.id,
                title=seed.title,
                position=position,
                created_by_id=actor.id,
                version=1,
            )
        )
        next_position = max(next_position, position + 1)

    touch_task(task)
    db.add(task)
    db.flush()
    db.refresh(checklist)
    return checklist


def update_checklist(
    db: Session,
    task: Task,
    checklist: TaskChecklist,
    payload: ChecklistUpdate,
) -> TaskChecklist:
    ensure_task_open(task)
    values = payload.model_dump(exclude_unset=True)
    if not values:
        return checklist
    for field, value in values.items():
        setattr(checklist, field, value)
    checklist.version += 1
    checklist.updated_at = datetime.now(UTC)
    touch_task(task)
    db.add_all([task, checklist])
    db.flush()
    return checklist


def delete_checklist(db: Session, task: Task, checklist: TaskChecklist) -> None:
    ensure_task_open(task)
    db.delete(checklist)
    touch_task(task)
    db.add(task)
    db.flush()


def create_item(
    db: Session,
    task: Task,
    checklist: TaskChecklist,
    actor: User,
    payload: ChecklistItemCreate,
) -> TaskChecklistItem:
    ensure_task_open(task)
    if payload.id is not None and db.get(TaskChecklistItem, payload.id) is not None:
        raise HTTPException(status_code=409, detail="La actividad ya existe")
    item = TaskChecklistItem(
        id=payload.id,
        checklist_id=checklist.id,
        title=payload.title,
        position=payload.position
        if payload.position is not None
        else _next_item_position(db, checklist.id),
        created_by_id=actor.id,
        version=1,
    )
    checklist.version += 1
    checklist.updated_at = datetime.now(UTC)
    touch_task(task)
    db.add_all([task, checklist, item])
    db.flush()
    return item


def update_item(
    db: Session,
    task: Task,
    checklist: TaskChecklist,
    item: TaskChecklistItem,
    payload: ChecklistItemUpdate,
) -> TaskChecklistItem:
    ensure_task_open(task)
    values = payload.model_dump(exclude_unset=True)
    if not values:
        return item
    for field, value in values.items():
        setattr(item, field, value)
    now = datetime.now(UTC)
    item.version += 1
    item.updated_at = now
    checklist.version += 1
    checklist.updated_at = now
    touch_task(task)
    db.add_all([task, checklist, item])
    db.flush()
    return item


def delete_item(
    db: Session,
    task: Task,
    checklist: TaskChecklist,
    item: TaskChecklistItem,
) -> None:
    ensure_task_open(task)
    db.delete(item)
    now = datetime.now(UTC)
    checklist.version += 1
    checklist.updated_at = now
    touch_task(task)
    db.add_all([task, checklist])
    db.flush()


def set_item_completed(
    db: Session,
    task: Task,
    checklist: TaskChecklist,
    item: TaskChecklistItem,
    actor: User,
    is_completed: bool,
) -> tuple[TaskChecklistItem, bool]:
    ensure_task_open(task)
    was_checklist_completed = checklist.is_completed
    now = datetime.now(UTC)
    item.is_completed = is_completed
    item.completed_by_id = actor.id if is_completed else None
    item.completed_at = now if is_completed else None
    item.updated_at = now
    item.version += 1
    checklist.version += 1
    checklist.updated_at = now
    touch_task(task)
    db.add_all([task, checklist, item])
    db.flush()
    db.refresh(checklist)
    became_completed = not was_checklist_completed and checklist.is_completed
    return item, became_completed


def set_checklist_completed(
    db: Session,
    task: Task,
    checklist: TaskChecklist,
    actor: User,
    is_completed: bool,
) -> bool:
    ensure_task_open(task)
    if not checklist.items:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Agregue actividades antes de completar el checklist",
        )
    was_completed = checklist.is_completed
    now = datetime.now(UTC)
    for item in checklist.items:
        if item.is_completed == is_completed:
            continue
        item.is_completed = is_completed
        item.completed_by_id = actor.id if is_completed else None
        item.completed_at = now if is_completed else None
        item.updated_at = now
        item.version += 1
        db.add(item)
    checklist.version += 1
    checklist.updated_at = now
    touch_task(task)
    db.add_all([task, checklist])
    db.flush()
    db.refresh(checklist)
    return not was_completed and checklist.is_completed
