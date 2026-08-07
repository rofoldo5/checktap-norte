from datetime import UTC, datetime
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, status
from sqlalchemy import select, update
from sqlalchemy.orm import Session, joinedload, selectinload

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.checklist import TaskChecklist, TaskChecklistItem
from app.models.task import Task
from app.models.user import User
from app.schemas.task import TaskCreate, TaskRead, TaskStatus, TaskUpdate
from app.services.department_service import (
    active_department_ids,
    require_department_access,
    resolve_task_department,
    validate_department_users,
)
from app.services.notification_service import notification_service
from app.services.task_permissions import (
    require_task_edit,
    require_task_reopen,
    require_task_view,
    require_task_work,
)
from app.services.websocket_manager import manager

router = APIRouter(prefix="/tasks", tags=["tasks"])


def task_query():
    return select(Task).execution_options(populate_existing=True).options(
        joinedload(Task.department),
        joinedload(Task.created_by).selectinload(User.department_memberships),
        joinedload(Task.assigned_to).selectinload(User.department_memberships),
        joinedload(Task.completed_by).selectinload(User.department_memberships),
        selectinload(Task.assignees).selectinload(User.department_memberships),
        selectinload(Task.checklists).joinedload(TaskChecklist.created_by),
        selectinload(Task.checklists)
        .selectinload(TaskChecklist.items)
        .joinedload(TaskChecklistItem.created_by),
        selectinload(Task.checklists)
        .selectinload(TaskChecklist.items)
        .joinedload(TaskChecklistItem.completed_by),
    )


def get_task_or_404(
    db: Session,
    task_id: UUID,
    current_user: User | None = None,
) -> Task:
    task = db.scalar(task_query().where(Task.id == task_id))
    if task is None:
        raise HTTPException(status_code=404, detail="Tarea no encontrada")
    if current_user is not None:
        require_task_view(current_user, task)
    return task


def set_task_assignees(db: Session, task: Task, assignee_ids: list[UUID]) -> None:
    users = validate_department_users(db, task.department_id, assignee_ids)
    task.assignees = users
    task.assigned_to_id = users[0].id if users else None


def schedule_task_notification(
    background_tasks: BackgroundTasks,
    *,
    event_type: str,
    task_id: UUID,
    actor_id: UUID,
) -> None:
    background_tasks.add_task(
        notification_service.notify_task_event,
        event_type=event_type,
        task_id=task_id,
        actor_id=actor_id,
    )


@router.get("", response_model=list[TaskRead])
def list_tasks(
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
    task_status: Annotated[TaskStatus | None, Query(alias="status")] = None,
    department_id: UUID | None = None,
) -> list[Task]:
    query = task_query().order_by(Task.created_at.desc())
    if not current_user.is_admin:
        query = query.where(Task.department_id.in_(active_department_ids(current_user)))
    if department_id is not None:
        require_department_access(current_user, department_id)
        query = query.where(Task.department_id == department_id)
    if task_status is not None:
        query = query.where(Task.status == task_status)
    return list(db.scalars(query).unique().all())


@router.get("/{task_id}", response_model=TaskRead)
def get_task(
    task_id: UUID,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> Task:
    return get_task_or_404(db, task_id, current_user)


@router.post("", response_model=TaskRead, status_code=status.HTTP_201_CREATED)
async def create_task(
    payload: TaskCreate,
    background_tasks: BackgroundTasks,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> Task:
    department = resolve_task_department(db, current_user, payload.department_id)
    if payload.id is not None and db.get(Task, payload.id) is not None:
        raise HTTPException(status_code=409, detail="La tarea ya existe")
    task = Task(
        id=payload.id,
        title=payload.title,
        description=payload.description,
        priority=payload.priority,
        department_id=department.id,
        created_by_id=current_user.id,
        version=1,
    )
    db.add(task)
    db.flush()
    set_task_assignees(db, task, payload.assignee_ids)
    db.commit()
    task = get_task_or_404(db, task.id, current_user)
    await manager.broadcast(
        {
            "event": "task.created",
            "task_id": str(task.id),
            "department_id": str(task.department_id),
            "version": task.version,
        }
    )
    schedule_task_notification(
        background_tasks,
        event_type="task_created",
        task_id=task.id,
        actor_id=current_user.id,
    )
    return task


@router.patch("/{task_id}", response_model=TaskRead)
async def update_task(
    task_id: UUID,
    payload: TaskUpdate,
    background_tasks: BackgroundTasks,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> Task:
    task = get_task_or_404(db, task_id, current_user)
    require_task_edit(current_user, task)
    values = payload.model_dump(exclude_unset=True)

    assignee_ids = values.pop("assignee_ids", None)
    values.pop("assigned_to_id", None)
    department_changed = False
    if "department_id" in values:
        department = resolve_task_department(db, current_user, values["department_id"])
        department_changed = task.department_id != department.id
        task.department_id = department.id
        values.pop("department_id")
    if department_changed and assignee_ids is None:
        assignee_ids = []

    for field, value in values.items():
        setattr(task, field, value)

    if assignee_ids is not None:
        set_task_assignees(db, task, assignee_ids)

    if values or assignee_ids is not None:
        task.version += 1
        task.updated_at = datetime.now(UTC)
    db.add(task)
    db.commit()
    task = get_task_or_404(db, task.id, current_user)
    await manager.broadcast(
        {
            "event": "task.updated",
            "task_id": str(task.id),
            "department_id": str(task.department_id),
            "version": task.version,
        }
    )
    if values or assignee_ids is not None:
        schedule_task_notification(
            background_tasks,
            event_type="task_updated",
            task_id=task.id,
            actor_id=current_user.id,
        )
    return task


@router.post("/{task_id}/start", response_model=TaskRead)
async def start_task(
    task_id: UUID,
    background_tasks: BackgroundTasks,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> Task:
    task = get_task_or_404(db, task_id, current_user)
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
    task = get_task_or_404(db, task_id, current_user)
    await manager.broadcast(
        {"event": "task.updated", "task_id": str(task.id), "version": task.version}
    )
    schedule_task_notification(
        background_tasks,
        event_type="task_started",
        task_id=task.id,
        actor_id=current_user.id,
    )
    return task


@router.post("/{task_id}/complete", response_model=TaskRead)
async def complete_task(
    task_id: UUID,
    background_tasks: BackgroundTasks,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> Task:
    task = get_task_or_404(db, task_id, current_user)
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
        task = get_task_or_404(db, task_id, current_user)
        completed_name = task.completed_by.name if task.completed_by else "otro usuario"
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"La tarea ya fue completada por {completed_name}",
        )
    db.commit()
    task = get_task_or_404(db, task_id, current_user)
    await manager.broadcast(
        {"event": "task.completed", "task_id": str(task.id), "version": task.version}
    )
    schedule_task_notification(
        background_tasks,
        event_type="task_completed",
        task_id=task.id,
        actor_id=current_user.id,
    )
    return task


@router.post("/{task_id}/reopen", response_model=TaskRead)
async def reopen_task(
    task_id: UUID,
    background_tasks: BackgroundTasks,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> Task:
    task = get_task_or_404(db, task_id, current_user)
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
    task = get_task_or_404(db, task_id, current_user)
    await manager.broadcast(
        {"event": "task.updated", "task_id": str(task.id), "version": task.version}
    )
    schedule_task_notification(
        background_tasks,
        event_type="task_reopened",
        task_id=task.id,
        actor_id=current_user.id,
    )
    return task
