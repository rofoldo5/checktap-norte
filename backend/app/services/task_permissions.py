from fastapi import HTTPException, status

from app.models.task import Task
from app.models.user import User
from app.services.department_service import is_department_member


def can_view_task(user: User, task: Task) -> bool:
    return is_department_member(user, task.department_id)


def can_edit_task(user: User, task: Task) -> bool:
    return user.is_admin or task.created_by_id == user.id


def can_work_task(user: User, task: Task) -> bool:
    # El trabajo es colaborativo: cualquier miembro activo del departamento
    # puede iniciar o completar una tarea. Los responsables son informativos.
    return is_department_member(user, task.department_id)


def can_reopen_task(user: User, task: Task) -> bool:
    return is_department_member(user, task.department_id)


def require_task_view(user: User, task: Task) -> None:
    if not can_view_task(user, task):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No pertenece al departamento de esta tarea",
        )


def require_task_edit(user: User, task: Task) -> None:
    if not can_edit_task(user, task):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo el creador o un administrador puede editar la tarea",
        )


def require_task_work(user: User, task: Task) -> None:
    if not can_work_task(user, task):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo un miembro del departamento puede cambiar el estado",
        )


def require_task_reopen(user: User, task: Task) -> None:
    if not can_reopen_task(user, task):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo un miembro del departamento puede reabrir la tarea",
        )
