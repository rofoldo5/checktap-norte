from datetime import UTC, datetime
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, update
from sqlalchemy.orm import Session, joinedload

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.task import Task
from app.models.user import User
from app.schemas.task import TaskCreate, TaskRead, TaskStatus, TaskUpdate
from app.services.task_permissions import (
    require_task_edit,
    require_task_reopen,
    require_task_work,
)
from app.services.websocket_manager import manager

router = APIRouter(prefix="/tasks", tags=["tasks"])


def task_query():
    return select(Task).execution_options(populate_existing=True).options(
        joinedload(Task.created_by),
        joinedload(Task.assigned_to),
        joinedload(Task.completed_by),
    )


def get_task_or_404(db: Session, task_id: UUID) -> Task:
    task = db.scalar(task_query().where(Task.id == task_id))
    if task is None:
        raise HTTPException(status_code=404, detail="Tarea no encontrada")
    return task


def ensure_assigned_user(db: Session, user_id: UUID | None) -> None:
    if user_id is None:
        return
    user = db.get(User, user_id)
    if user is None or not user.is_active:
        raise HTTPException(status_code=400, detail="Usuario asignado no valido")


@router.get("", response_model=list[TaskRead])
def list_tasks(
    db: Annotated[Session, Depends(get_db)],
    _: Annotated[User, Depends(get_current_user)],
    task_status: Annotated[TaskStatus | None, Query(alias="status")] = None,
) -> list[Task]:
    query = task_query().order_by(Task.created_at.desc())
    if task_status is not None:
        query = query.where(Task.status == task_status)
    return list(db.scalars(query).unique().all())


@router.get("/{task_id}", response_model=TaskRead)
def get_task(
    task_id: UUID,
    db: Annotated[Session, Depends(get_db)],
    _: Annotated[User, Depends(get_current_user)],
) -> Task:
    return get_task_or_404(db, task_id)


@router.post("", response_model=TaskRead, status_code=status.HTTP_201_CREATED)
async def create_task(
    payload: TaskCreate,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> Task:
    ensure_assigned_user(db, payload.assigned_to_id)
    if payload.id is not None and db.get(Task, payload.id) is not None:
        raise HTTPException(status_code=409, detail="La tarea ya existe")
    task = Task(
        id=payload.id,
        title=payload.title,
        description=payload.description,
        priority=payload.priority,
        created_by_id=current_user.id,
        assigned_to_id=payload.assigned_to_id,
        version=1,
    )
    db.add(task)
    db.commit()
    task = get_task_or_404(db, task.id)
    await manager.broadcast(
        {"event": "task.created", "task_id": str(task.id), "version": task.version}
    )
    return task


@router.patch("/{task_id}", response_model=TaskRead)
async def update_task(
    task_id: UUID,
    payload: TaskUpdate,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> Task:
    task = get_task_or_404(db, task_id)
    require_task_edit(current_user, task)
    values = payload.model_dump(exclude_unset=True)

    if "assigned_to_id" in values:
        ensure_assigned_user(db, values["assigned_to_id"])

    for field, value in values.items():
        setattr(task, field, value)

    if values:
        task.version += 1
        task.updated_at = datetime.now(UTC)
    db.add(task)
    db.commit()
    task = get_task_or_404(db, task.id)
    await manager.broadcast(
        {"event": "task.updated", "task_id": str(task.id), "version": task.version}
    )
    return task


@router.post("/{task_id}/start", response_model=TaskRead)
async def start_task(
    task_id: UUID,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> Task:
    task = get_task_or_404(db, task_id)
    require_task_work(current_user, task)
    if task.status == "COMPLETADA":
        raise HTTPException(status_code=400, detail="La tarea ya esta completada")

    now = datetime.now(UTC)
    result = db.execute(
        update(Task)
        .where(Task.id == task_id, Task.status != "COMPLETADA")
        .values(
            status="EN_PROGRESO",
            completed_by_id=None,
            completed_at=None,
            updated_at=now,
            version=Task.version + 1,
        )
    )
    if result.rowcount == 0:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="La tarea fue completada por otro usuario",
        )
    db.commit()
    task = get_task_or_404(db, task_id)
    await manager.broadcast(
        {"event": "task.updated", "task_id": str(task.id), "version": task.version}
    )
    return task


@router.post("/{task_id}/complete", response_model=TaskRead)
async def complete_task(
    task_id: UUID,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> Task:
    task = get_task_or_404(db, task_id)
    require_task_work(current_user, task)
    if task.status == "COMPLETADA":
        completed_name = task.completed_by.name if task.completed_by else "otro usuario"
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"La tarea ya fue completada por {completed_name}",
        )

    now = datetime.now(UTC)
    result = db.execute(
        update(Task)
        .where(Task.id == task_id, Task.status != "COMPLETADA")
        .values(
            status="COMPLETADA",
            completed_by_id=current_user.id,
            completed_at=now,
            updated_at=now,
            version=Task.version + 1,
        )
    )
    if result.rowcount == 0:
        db.rollback()
        task = get_task_or_404(db, task_id)
        completed_name = task.completed_by.name if task.completed_by else "otro usuario"
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"La tarea ya fue completada por {completed_name}",
        )
    db.commit()
    task = get_task_or_404(db, task_id)
    await manager.broadcast(
        {
            "event": "task.completed",
            "task_id": str(task.id),
            "version": task.version,
        }
    )
    return task


@router.post("/{task_id}/reopen", response_model=TaskRead)
async def reopen_task(
    task_id: UUID,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> Task:
    task = get_task_or_404(db, task_id)
    require_task_reopen(current_user, task)
    now = datetime.now(UTC)
    db.execute(
        update(Task)
        .where(Task.id == task_id)
        .values(
            status="PENDIENTE",
            completed_by_id=None,
            completed_at=None,
            updated_at=now,
            version=Task.version + 1,
        )
    )
    db.commit()
    task = get_task_or_404(db, task_id)
    await manager.broadcast(
        {"event": "task.updated", "task_id": str(task.id), "version": task.version}
    )
    return task
