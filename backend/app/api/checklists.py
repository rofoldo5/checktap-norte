from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Depends, Response, status
from sqlalchemy.orm import Session

from app.api.tasks import get_task_or_404
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.user import User
from app.schemas.checklist import (
    ChecklistCreate,
    ChecklistItemCreate,
    ChecklistItemUpdate,
    ChecklistSetCompleted,
    ChecklistUpdate,
)
from app.schemas.task import TaskRead
from app.services.checklist_service import (
    create_checklist,
    create_item,
    delete_checklist,
    delete_item,
    get_checklist_or_404,
    get_item_or_404,
    set_checklist_completed,
    set_item_completed,
    update_checklist,
    update_item,
)
from app.services.notification_service import notification_service
from app.services.task_permissions import require_task_work
from app.services.websocket_manager import manager

router = APIRouter(prefix="/tasks/{task_id}/checklists", tags=["checklists"])


async def _broadcast(task) -> None:
    await manager.broadcast(
        {
            "event": "task.checklist.updated",
            "task_id": str(task.id),
            "department_id": str(task.department_id),
            "version": task.version,
        }
    )


def _notify_completed(
    background_tasks: BackgroundTasks,
    *,
    task_id: UUID,
    checklist_id: UUID,
    actor_id: UUID,
) -> None:
    background_tasks.add_task(
        notification_service.notify_checklist_completed,
        task_id=task_id,
        checklist_id=checklist_id,
        actor_id=actor_id,
    )


@router.post("", response_model=TaskRead, status_code=status.HTTP_201_CREATED)
async def add_checklist(
    task_id: UUID,
    payload: ChecklistCreate,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    task = get_task_or_404(db, task_id, current_user)
    require_task_work(current_user, task)
    create_checklist(db, task, current_user, payload)
    db.commit()
    task = get_task_or_404(db, task_id, current_user)
    await _broadcast(task)
    return task


@router.patch("/{checklist_id}", response_model=TaskRead)
async def edit_checklist(
    task_id: UUID,
    checklist_id: UUID,
    payload: ChecklistUpdate,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    task = get_task_or_404(db, task_id, current_user)
    require_task_work(current_user, task)
    checklist = get_checklist_or_404(db, task, checklist_id)
    update_checklist(db, task, checklist, payload)
    db.commit()
    task = get_task_or_404(db, task_id, current_user)
    await _broadcast(task)
    return task


@router.delete("/{checklist_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_checklist(
    task_id: UUID,
    checklist_id: UUID,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    task = get_task_or_404(db, task_id, current_user)
    require_task_work(current_user, task)
    checklist = get_checklist_or_404(db, task, checklist_id)
    delete_checklist(db, task, checklist)
    db.commit()
    await _broadcast(task)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/{checklist_id}/items", response_model=TaskRead, status_code=status.HTTP_201_CREATED)
async def add_item(
    task_id: UUID,
    checklist_id: UUID,
    payload: ChecklistItemCreate,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    task = get_task_or_404(db, task_id, current_user)
    require_task_work(current_user, task)
    checklist = get_checklist_or_404(db, task, checklist_id)
    create_item(db, task, checklist, current_user, payload)
    db.commit()
    task = get_task_or_404(db, task_id, current_user)
    await _broadcast(task)
    return task


@router.patch("/{checklist_id}/items/{item_id}", response_model=TaskRead)
async def edit_item(
    task_id: UUID,
    checklist_id: UUID,
    item_id: UUID,
    payload: ChecklistItemUpdate,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    task = get_task_or_404(db, task_id, current_user)
    require_task_work(current_user, task)
    checklist = get_checklist_or_404(db, task, checklist_id)
    item = get_item_or_404(db, checklist, item_id)
    update_item(db, task, checklist, item, payload)
    db.commit()
    task = get_task_or_404(db, task_id, current_user)
    await _broadcast(task)
    return task


@router.delete("/{checklist_id}/items/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_item(
    task_id: UUID,
    checklist_id: UUID,
    item_id: UUID,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    task = get_task_or_404(db, task_id, current_user)
    require_task_work(current_user, task)
    checklist = get_checklist_or_404(db, task, checklist_id)
    item = get_item_or_404(db, checklist, item_id)
    delete_item(db, task, checklist, item)
    db.commit()
    await _broadcast(task)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/{checklist_id}/items/{item_id}/state", response_model=TaskRead)
async def change_item_state(
    task_id: UUID,
    checklist_id: UUID,
    item_id: UUID,
    payload: ChecklistSetCompleted,
    background_tasks: BackgroundTasks,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    task = get_task_or_404(db, task_id, current_user)
    require_task_work(current_user, task)
    checklist = get_checklist_or_404(db, task, checklist_id)
    item = get_item_or_404(db, checklist, item_id)
    _, became_completed = set_item_completed(
        db,
        task,
        checklist,
        item,
        current_user,
        payload.is_completed,
    )
    db.commit()
    task = get_task_or_404(db, task_id, current_user)
    await _broadcast(task)
    if became_completed:
        _notify_completed(
            background_tasks,
            task_id=task.id,
            checklist_id=checklist.id,
            actor_id=current_user.id,
        )
    return task


@router.post("/{checklist_id}/state", response_model=TaskRead)
async def change_checklist_state(
    task_id: UUID,
    checklist_id: UUID,
    payload: ChecklistSetCompleted,
    background_tasks: BackgroundTasks,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    task = get_task_or_404(db, task_id, current_user)
    require_task_work(current_user, task)
    checklist = get_checklist_or_404(db, task, checklist_id)
    became_completed = set_checklist_completed(
        db,
        task,
        checklist,
        current_user,
        payload.is_completed,
    )
    db.commit()
    task = get_task_or_404(db, task_id, current_user)
    await _broadcast(task)
    if became_completed:
        _notify_completed(
            background_tasks,
            task_id=task.id,
            checklist_id=checklist.id,
            actor_id=current_user.id,
        )
    return task
