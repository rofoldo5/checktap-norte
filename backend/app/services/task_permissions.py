from fastapi import HTTPException, status

from app.models.task import Task
from app.models.user import User


def can_edit_task(user: User, task: Task) -> bool:
    return user.is_admin or task.created_by_id == user.id


def can_work_task(user: User, task: Task) -> bool:
    return (
        user.is_admin
        or task.created_by_id == user.id
        or task.assigned_to_id == user.id
    )


def can_reopen_task(user: User, task: Task) -> bool:
    return user.is_admin or task.created_by_id == user.id


def require_task_edit(user: User, task: Task) -> None:
    if not can_edit_task(user, task):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo el creador o un administrador puede editar o reasignar la tarea",
        )


def require_task_work(user: User, task: Task) -> None:
    if not can_work_task(user, task):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "Solo el usuario asignado, el creador o un administrador "
                "puede cambiar el estado de la tarea"
            ),
        )


def require_task_reopen(user: User, task: Task) -> None:
    if not can_reopen_task(user, task):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo el creador o un administrador puede reabrir la tarea",
        )
