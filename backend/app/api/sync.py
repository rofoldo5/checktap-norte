from datetime import UTC, datetime
from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.tasks import ensure_assigned_user, get_task_or_404
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.processed_operation import ProcessedOperation
from app.models.task import Task
from app.models.user import User
from app.schemas.sync import (
    SyncOperation,
    SyncOperationResult,
    SyncRequest,
    SyncResponse,
)
from app.schemas.task import TaskCreate, TaskRead, TaskUpdate
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
) -> tuple[SyncOperationResult, str | None]:
    existing_task = db.get(Task, operation.entity_id)
    if existing_task is not None:
        task = get_task_or_404(db, operation.entity_id)
        return (
            SyncOperationResult(
                operation_id=operation.operation_id,
                status="DUPLICATE",
                detail="La tarea ya existe en el servidor",
                task=_task_read(task),
            ),
            None,
        )

    payload = TaskCreate.model_validate(
        {
            **operation.payload,
            "id": operation.entity_id,
        }
    )
    ensure_assigned_user(db, payload.assigned_to_id)
    task = Task(
        id=operation.entity_id,
        title=payload.title,
        description=payload.description,
        priority=payload.priority,
        created_by_id=current_user.id,
        assigned_to_id=payload.assigned_to_id,
        version=1,
    )
    db.add(task)
    db.flush()
    task = get_task_or_404(db, task.id)
    return (
        SyncOperationResult(
            operation_id=operation.operation_id,
            status="APPLIED",
            task=_task_read(task),
        ),
        "task.created",
    )


def _apply_update(
    operation: SyncOperation,
    db: Session,
    current_user: User,
) -> tuple[SyncOperationResult, str | None]:
    task = get_task_or_404(db, operation.entity_id)
    require_task_edit(current_user, task)
    if task.version != operation.base_version:
        return _version_conflict(operation, task), None

    payload = TaskUpdate.model_validate(operation.payload)
    values = payload.model_dump(exclude_unset=True)
    if "assigned_to_id" in values:
        ensure_assigned_user(db, values["assigned_to_id"])

    for field, value in values.items():
        setattr(task, field, value)

    if values:
        task.version += 1
        task.updated_at = datetime.now(UTC)
    db.add(task)
    db.flush()
    task = get_task_or_404(db, task.id)
    return (
        SyncOperationResult(
            operation_id=operation.operation_id,
            status="APPLIED",
            task=_task_read(task),
        ),
        "task.updated",
    )


def _apply_transition(
    operation: SyncOperation,
    db: Session,
    current_user: User,
) -> tuple[SyncOperationResult, str | None]:
    task = get_task_or_404(db, operation.entity_id)
    if task.version != operation.base_version:
        return _version_conflict(operation, task), None

    now = datetime.now(UTC)
    event = "task.updated"

    if operation.operation_type == "START_TASK":
        require_task_work(current_user, task)
        if task.status == "COMPLETADA":
            return _conflict(operation, task, "La tarea ya esta completada"), None
        task.status = "EN_PROGRESO"
        task.completed_by_id = None
        task.completed_at = None
    elif operation.operation_type == "COMPLETE_TASK":
        require_task_work(current_user, task)
        if task.status == "COMPLETADA":
            completed_name = (
                task.completed_by.name if task.completed_by else "otro usuario"
            )
            return (
                _conflict(
                    operation,
                    task,
                    f"La tarea ya fue completada por {completed_name}",
                ),
                None,
            )
        task.status = "COMPLETADA"
        task.completed_by_id = current_user.id
        task.completed_at = now
        event = "task.completed"
    elif operation.operation_type == "REOPEN_TASK":
        require_task_reopen(current_user, task)
        task.status = "PENDIENTE"
        task.completed_by_id = None
        task.completed_at = None
    else:
        return (
            SyncOperationResult(
                operation_id=operation.operation_id,
                status="ERROR",
                detail=f"Operacion no soportada: {operation.operation_type}",
            ),
            None,
        )

    task.version += 1
    task.updated_at = now
    db.add(task)
    db.flush()
    task = get_task_or_404(db, task.id)
    return (
        SyncOperationResult(
            operation_id=operation.operation_id,
            status="APPLIED",
            task=_task_read(task),
        ),
        event,
    )


def _process_operation(
    operation: SyncOperation,
    db: Session,
    current_user: User,
) -> tuple[SyncOperationResult, str | None, bool]:
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
                True,
            )
        return _stored_result(existing), None, True

    if operation.operation_type == "CREATE_TASK":
        result, event = _apply_create(operation, db, current_user)
    elif operation.operation_type == "UPDATE_TASK":
        result, event = _apply_update(operation, db, current_user)
    else:
        result, event = _apply_transition(operation, db, current_user)
    return result, event, False


@router.post("/operations", response_model=SyncResponse)
async def process_operations(
    payload: SyncRequest,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> SyncResponse:
    results: list[SyncOperationResult] = []

    for operation in payload.operations:
        event: str | None = None
        try:
            result, event, already_stored = _process_operation(
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

        if event is not None and result.task is not None:
            await manager.broadcast(
                {
                    "event": event,
                    "task_id": str(result.task.id),
                    "version": result.task.version,
                }
            )

    return SyncResponse(results=results)
