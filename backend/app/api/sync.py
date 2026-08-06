from datetime import UTC, datetime
from typing import Annotated

from fastapi import APIRouter, BackgroundTasks, Depends
from sqlalchemy.orm import Session

from app.api.tasks import (
    get_task_or_404,
    schedule_task_notification,
    set_task_assignees,
)
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.processed_operation import ProcessedOperation
from app.models.task import Task
from app.models.user import User
from app.schemas.sync import SyncOperation, SyncOperationResult, SyncRequest, SyncResponse
from app.schemas.task import TaskCreate, TaskRead, TaskUpdate
from app.services.department_service import resolve_task_department
from app.services.task_permissions import (
    require_task_edit,
    require_task_reopen,
    require_task_work,
)
from app.services.websocket_manager import manager

router = APIRouter(prefix="/sync", tags=["sync"])


def _task_read(task: Task) -> TaskRead:
    return TaskRead.model_validate(task)


def _stored_result(existing: ProcessedOperation) -> SyncOperationResult:
    return SyncOperationResult.model_validate_json(existing.response_json)


def _conflict(
    operation: SyncOperation,
    task: Task,
    detail: str,
) -> SyncOperationResult:
    return SyncOperationResult(
        operation_id=operation.operation_id,
        status="CONFLICT",
        detail=detail,
        task=_task_read(task),
    )


def _version_conflict(operation: SyncOperation, task: Task) -> SyncOperationResult:
    return _conflict(
        operation,
        task,
        (
            "La tarea cambio en otro dispositivo. "
            f"Version local {operation.base_version}; "
            f"version servidor {task.version}."
        ),
    )


def _apply_create(
    operation: SyncOperation,
    db: Session,
    current_user: User,
) -> tuple[SyncOperationResult, str | None, str | None]:
    existing_task = db.get(Task, operation.entity_id)
    if existing_task is not None:
        task = get_task_or_404(db, operation.entity_id, current_user)
        return (
            SyncOperationResult(
                operation_id=operation.operation_id,
                status="DUPLICATE",
                detail="La tarea ya existe en el servidor",
                task=_task_read(task),
            ),
            None,
            None,
        )

    payload = TaskCreate.model_validate({**operation.payload, "id": operation.entity_id})
    department = resolve_task_department(db, current_user, payload.department_id)
    task = Task(
        id=operation.entity_id,
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
    db.flush()
    task = get_task_or_404(db, task.id, current_user)
    return (
        SyncOperationResult(
            operation_id=operation.operation_id,
            status="APPLIED",
            task=_task_read(task),
        ),
        "task.created",
        "task_created",
    )


def _apply_update(
    operation: SyncOperation,
    db: Session,
    current_user: User,
) -> tuple[SyncOperationResult, str | None, str | None]:
    task = get_task_or_404(db, operation.entity_id, current_user)
    require_task_edit(current_user, task)
    if task.version != operation.base_version:
        return _version_conflict(operation, task), None, None

    payload = TaskUpdate.model_validate(operation.payload)
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
    db.flush()
    task = get_task_or_404(db, task.id, current_user)
    return (
        SyncOperationResult(
            operation_id=operation.operation_id,
            status="APPLIED",
            task=_task_read(task),
        ),
        "task.updated",
        "task_updated" if values or assignee_ids is not None else None,
    )


def _apply_transition(
    operation: SyncOperation,
    db: Session,
    current_user: User,
) -> tuple[SyncOperationResult, str | None, str | None]:
    task = get_task_or_404(db, operation.entity_id, current_user)
    if task.version != operation.base_version:
        return _version_conflict(operation, task), None, None

    now = datetime.now(UTC)
    event = "task.updated"
    notification_event: str | None = None

    if operation.operation_type == "START_TASK":
        require_task_work(current_user, task)
        if task.status == "COMPLETADA":
            return _conflict(operation, task, "La tarea ya esta completada"), None, None
        task.status = "EN_PROGRESO"
        task.completed_by_id = None
        task.completed_at = None
        notification_event = "task_started"
    elif operation.operation_type == "COMPLETE_TASK":
        require_task_work(current_user, task)
        if task.status == "COMPLETADA":
            completed_name = task.completed_by.name if task.completed_by else "otro usuario"
            return (
                _conflict(
                    operation,
                    task,
                    f"La tarea ya fue completada por {completed_name}",
                ),
                None,
                None,
            )
        task.status = "COMPLETADA"
        task.completed_by_id = current_user.id
        task.completed_at = now
        event = "task.completed"
        notification_event = "task_completed"
    elif operation.operation_type == "REOPEN_TASK":
        require_task_reopen(current_user, task)
        task.status = "PENDIENTE"
        task.completed_by_id = None
        task.completed_at = None
        notification_event = "task_reopened"
    else:
        return (
            SyncOperationResult(
                operation_id=operation.operation_id,
                status="ERROR",
                detail=f"Operacion no soportada: {operation.operation_type}",
            ),
            None,
            None,
        )

    task.version += 1
    task.updated_at = now
    db.add(task)
    db.flush()
    task = get_task_or_404(db, task.id, current_user)
    return (
        SyncOperationResult(
            operation_id=operation.operation_id,
            status="APPLIED",
            task=_task_read(task),
        ),
        event,
        notification_event,
    )


def _process_operation(
    operation: SyncOperation,
    db: Session,
    current_user: User,
) -> tuple[SyncOperationResult, str | None, str | None, bool]:
    existing = db.get(ProcessedOperation, operation.operation_id)
    if existing is not None:
        if existing.user_id != current_user.id:
            return (
                SyncOperationResult(
                    operation_id=operation.operation_id,
                    status="ERROR",
                    detail="El identificador de operacion pertenece a otro usuario",
                ),
                None,
                None,
                True,
            )
        return _stored_result(existing), None, None, True

    if operation.operation_type == "CREATE_TASK":
        result, event, notification_event = _apply_create(operation, db, current_user)
    elif operation.operation_type == "UPDATE_TASK":
        result, event, notification_event = _apply_update(operation, db, current_user)
    else:
        result, event, notification_event = _apply_transition(
            operation,
            db,
            current_user,
        )
    return result, event, notification_event, False


@router.post("/operations", response_model=SyncResponse)
async def process_operations(
    payload: SyncRequest,
    background_tasks: BackgroundTasks,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> SyncResponse:
    results: list[SyncOperationResult] = []

    for operation in payload.operations:
        event: str | None = None
        notification_event: str | None = None
        try:
            result, event, notification_event, already_stored = _process_operation(
                operation,
                db,
                current_user,
            )
            if not already_stored:
                db.add(
                    ProcessedOperation(
                        operation_id=operation.operation_id,
                        user_id=current_user.id,
                        operation_type=operation.operation_type,
                        entity_id=operation.entity_id,
                        result_status=result.status,
                        response_json=result.model_dump_json(),
                    )
                )
                db.commit()
            results.append(result)
        except Exception as error:
            db.rollback()
            result = SyncOperationResult(
                operation_id=operation.operation_id,
                status="ERROR",
                detail=str(error),
            )
            db.add(
                ProcessedOperation(
                    operation_id=operation.operation_id,
                    user_id=current_user.id,
                    operation_type=operation.operation_type,
                    entity_id=operation.entity_id,
                    result_status=result.status,
                    response_json=result.model_dump_json(),
                )
            )
            db.commit()
            results.append(result)
            event = None
            notification_event = None

        if event is not None and result.task is not None:
            await manager.broadcast(
                {
                    "event": event,
                    "task_id": str(result.task.id),
                    "department_id": str(result.task.department.id),
                    "version": result.task.version,
                }
            )

        if notification_event is not None and result.task is not None:
            schedule_task_notification(
                background_tasks,
                event_type=notification_event,
                task_id=result.task.id,
                actor_id=current_user.id,
            )

    return SyncResponse(results=results)
