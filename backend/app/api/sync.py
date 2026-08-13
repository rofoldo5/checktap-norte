from datetime import UTC, datetime
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Depends
from sqlalchemy.orm import Session

from app.api.tasks import (
    get_task_or_404,
    schedule_task_notification,
    set_task_assignees,
)
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.control import ControlCheck, ControlSection
from app.models.processed_operation import ProcessedOperation
from app.models.task import Task
from app.models.user import User
from app.schemas.control import (
    ControlCheckComplete,
    ControlCheckCreate,
    ControlCheckUpdate,
    ControlSectionCreate,
    ControlSectionUpdate,
)
from app.schemas.checklist import (
    ChecklistCreate,
    ChecklistItemCreate,
    ChecklistItemUpdate,
    ChecklistSetCompleted,
    ChecklistUpdate,
)
from app.schemas.sync import SyncOperation, SyncOperationResult, SyncRequest, SyncResponse
from app.schemas.task import TaskCreate, TaskRead, TaskUpdate
from app.services.control_permissions import (
    require_control_check_create,
    require_control_check_edit,
    require_control_check_work,
    require_control_section_manage,
)
from app.services.control_service import (
    check_read,
    complete_control_check,
    configure_control_schedule,
    get_control_check,
    get_control_section,
    reopen_control_check,
    section_read,
    set_control_assignees,
    update_control_check_from_payload,
)
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
from app.services.department_service import resolve_task_department
from app.services.notification_service import notification_service
from app.services.recurrence_service import (
    configure_recurrence,
    configure_recurrence_from_changes,
    pop_recurrence_changes,
)
from app.services.task_permissions import (
    require_task_edit,
    require_task_reopen,
    require_task_work,
)
from app.services.websocket_manager import manager

router = APIRouter(prefix="/sync", tags=["sync"])

CHECKLIST_OPERATION_TYPES = {
    "CREATE_CHECKLIST",
    "UPDATE_CHECKLIST",
    "DELETE_CHECKLIST",
    "CREATE_CHECKLIST_ITEM",
    "UPDATE_CHECKLIST_ITEM",
    "DELETE_CHECKLIST_ITEM",
    "SET_CHECKLIST_ITEM_STATE",
    "SET_CHECKLIST_STATE",
}


CONTROL_SECTION_OPERATION_TYPES = {
    "CREATE_CONTROL_SECTION",
    "UPDATE_CONTROL_SECTION",
    "ARCHIVE_CONTROL_SECTION",
}

CONTROL_CHECK_OPERATION_TYPES = {
    "CREATE_CONTROL_CHECK",
    "UPDATE_CONTROL_CHECK",
    "COMPLETE_CONTROL_CHECK",
    "REOPEN_CONTROL_CHECK",
    "DELETE_CONTROL_CHECK",
}


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
) -> tuple[SyncOperationResult, str | None, str | None, UUID | None]:
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
    configure_recurrence(
        task,
        recurrence_type=payload.recurrence_type,
        recurrence_interval=payload.recurrence_interval,
        recurrence_unit=payload.recurrence_unit,
        recurrence_start_at=payload.recurrence_start_at,
        recurrence_timezone=payload.recurrence_timezone,
        notifications_enabled=payload.notifications_enabled,
        reminder_minutes_before=payload.reminder_minutes_before,
    )
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
        None,
    )


def _apply_update(
    operation: SyncOperation,
    db: Session,
    current_user: User,
) -> tuple[SyncOperationResult, str | None, str | None, UUID | None]:
    task = get_task_or_404(db, operation.entity_id, current_user)
    require_task_edit(current_user, task)
    if task.version != operation.base_version:
        return _version_conflict(operation, task), None, None, None

    payload = TaskUpdate.model_validate(operation.payload)
    values = payload.model_dump(exclude_unset=True)
    assignee_ids = values.pop("assignee_ids", None)
    values.pop("assigned_to_id", None)
    recurrence_changes = pop_recurrence_changes(values)
    recurrence_changed = False
    if recurrence_changes:
        recurrence_changed = configure_recurrence_from_changes(
            task,
            recurrence_changes,
        )

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

    if values or assignee_ids is not None or recurrence_changed:
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
        "task_updated"
        if values or assignee_ids is not None or recurrence_changed
        else None,
        None,
    )


def _apply_transition(
    operation: SyncOperation,
    db: Session,
    current_user: User,
) -> tuple[SyncOperationResult, str | None, str | None, UUID | None]:
    task = get_task_or_404(db, operation.entity_id, current_user)
    if task.version != operation.base_version:
        return _version_conflict(operation, task), None, None, None

    now = datetime.now(UTC)
    event = "task.updated"
    notification_event: str | None = None

    if operation.operation_type == "START_TASK":
        require_task_work(current_user, task)
        if task.status == "COMPLETADA":
            return _conflict(operation, task, "La tarea ya esta completada"), None, None, None
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
        None,
    )


def _uuid_value(payload: dict[str, object], field: str) -> UUID:
    value = payload.get(field)
    if value is None:
        raise ValueError(f"Falta el campo {field}")
    return UUID(str(value))


def _apply_checklist_operation(
    operation: SyncOperation,
    db: Session,
    current_user: User,
) -> tuple[SyncOperationResult, str | None, str | None, UUID | None]:
    task = get_task_or_404(db, operation.entity_id, current_user)
    require_task_work(current_user, task)
    if task.version != operation.base_version:
        return _version_conflict(operation, task), None, None, None

    payload = dict(operation.payload)
    checklist_id: UUID | None = None
    became_completed = False

    if operation.operation_type == "CREATE_CHECKLIST":
        checklist = create_checklist(
            db,
            task,
            current_user,
            ChecklistCreate.model_validate(payload),
        )
        checklist_id = checklist.id
    else:
        checklist_id = _uuid_value(payload, "checklist_id")
        checklist = get_checklist_or_404(db, task, checklist_id)

        if operation.operation_type == "UPDATE_CHECKLIST":
            values = {key: value for key, value in payload.items() if key != "checklist_id"}
            update_checklist(
                db,
                task,
                checklist,
                ChecklistUpdate.model_validate(values),
            )
        elif operation.operation_type == "DELETE_CHECKLIST":
            delete_checklist(db, task, checklist)
        elif operation.operation_type == "CREATE_CHECKLIST_ITEM":
            values = {key: value for key, value in payload.items() if key != "checklist_id"}
            create_item(
                db,
                task,
                checklist,
                current_user,
                ChecklistItemCreate.model_validate(values),
            )
        elif operation.operation_type == "SET_CHECKLIST_STATE":
            state = ChecklistSetCompleted.model_validate(payload)
            became_completed = set_checklist_completed(
                db,
                task,
                checklist,
                current_user,
                state.is_completed,
            )
        else:
            item_id = _uuid_value(payload, "item_id")
            item = get_item_or_404(db, checklist, item_id)
            if operation.operation_type == "UPDATE_CHECKLIST_ITEM":
                values = {
                    key: value
                    for key, value in payload.items()
                    if key not in {"checklist_id", "item_id"}
                }
                update_item(
                    db,
                    task,
                    checklist,
                    item,
                    ChecklistItemUpdate.model_validate(values),
                )
            elif operation.operation_type == "DELETE_CHECKLIST_ITEM":
                delete_item(db, task, checklist, item)
            elif operation.operation_type == "SET_CHECKLIST_ITEM_STATE":
                state = ChecklistSetCompleted.model_validate(payload)
                _, became_completed = set_item_completed(
                    db,
                    task,
                    checklist,
                    item,
                    current_user,
                    state.is_completed,
                )
            else:
                raise ValueError(f"Operacion no soportada: {operation.operation_type}")

    db.flush()
    task = get_task_or_404(db, task.id, current_user)
    return (
        SyncOperationResult(
            operation_id=operation.operation_id,
            status="APPLIED",
            task=_task_read(task),
        ),
        "task.checklist.updated",
        "checklist_completed" if became_completed else None,
        checklist_id if became_completed else None,
    )



def _control_section_conflict(
    operation: SyncOperation,
    section: ControlSection,
    detail: str,
) -> SyncOperationResult:
    return SyncOperationResult(
        operation_id=operation.operation_id,
        status="CONFLICT",
        detail=detail,
        control_section=section_read(section),
    )


def _control_check_conflict(
    operation: SyncOperation,
    check: ControlCheck,
    detail: str,
) -> SyncOperationResult:
    return SyncOperationResult(
        operation_id=operation.operation_id,
        status="CONFLICT",
        detail=detail,
        control_check=check_read(check),
    )


def _apply_control_section_operation(
    operation: SyncOperation,
    db: Session,
    current_user: User,
) -> tuple[SyncOperationResult, str | None]:
    if operation.operation_type == "CREATE_CONTROL_SECTION":
        require_control_section_manage(current_user)
        existing = db.get(ControlSection, operation.entity_id)
        if existing is not None:
            section = get_control_section(db, operation.entity_id)
            return (
                SyncOperationResult(
                    operation_id=operation.operation_id,
                    status="DUPLICATE",
                    detail="La seccion ya existe en el servidor",
                    control_section=section_read(section),
                ),
                None,
            )
        payload = ControlSectionCreate.model_validate(
            {**operation.payload, "id": operation.entity_id}
        )
        department = resolve_task_department(db, current_user, payload.department_id)
        section = ControlSection(
            id=operation.entity_id,
            name=payload.name,
            description=payload.description,
            icon_key=payload.icon_key,
            department_id=department.id,
            created_by_id=current_user.id,
            version=1,
        )
        db.add(section)
        db.flush()
        section = get_control_section(db, section.id)
        return (
            SyncOperationResult(
                operation_id=operation.operation_id,
                status="APPLIED",
                control_section=section_read(section),
            ),
            "control.section.created",
        )

    section = get_control_section(db, operation.entity_id)
    require_control_section_manage(current_user, section)
    if section.version != operation.base_version:
        return (
            _control_section_conflict(
                operation,
                section,
                (
                    "La seccion cambio en otro dispositivo. "
                    f"Version local {operation.base_version}; "
                    f"version servidor {section.version}."
                ),
            ),
            None,
        )

    if operation.operation_type == "ARCHIVE_CONTROL_SECTION":
        section.is_active = False
    else:
        payload = ControlSectionUpdate.model_validate(operation.payload)
        values = payload.model_dump(exclude_unset=True)
        if "department_id" in values:
            department = resolve_task_department(
                db,
                current_user,
                values.pop("department_id"),
            )
            section.department_id = department.id
        for key, value in values.items():
            setattr(section, key, value)
    section.version += 1
    section.updated_at = datetime.now(UTC)
    db.add(section)
    db.flush()
    section = get_control_section(db, section.id)
    return (
        SyncOperationResult(
            operation_id=operation.operation_id,
            status="APPLIED",
            control_section=section_read(section),
        ),
        "control.section.archived"
        if operation.operation_type == "ARCHIVE_CONTROL_SECTION"
        else "control.section.updated",
    )


def _apply_control_check_operation(
    operation: SyncOperation,
    db: Session,
    current_user: User,
) -> tuple[SyncOperationResult, str | None]:
    if operation.operation_type == "CREATE_CONTROL_CHECK":
        existing = db.get(ControlCheck, operation.entity_id)
        if existing is not None:
            check = get_control_check(db, operation.entity_id)
            return (
                SyncOperationResult(
                    operation_id=operation.operation_id,
                    status="DUPLICATE",
                    detail="El control ya existe en el servidor",
                    control_check=check_read(check),
                ),
                None,
            )
        raw = dict(operation.payload)
        section_id = UUID(str(raw.pop("section_id")))
        section = get_control_section(db, section_id)
        require_control_check_create(current_user, section)
        payload = ControlCheckCreate.model_validate(
            {**raw, "id": operation.entity_id}
        )
        check = ControlCheck(
            id=operation.entity_id,
            section_id=section.id,
            title=payload.title,
            description=payload.description,
            reference=payload.reference,
            contact=payload.contact,
            notes=payload.notes,
            priority=payload.priority,
            status="PENDIENTE",
            due_at=payload.due_at,
            timezone=payload.timezone,
            recurrence_type=payload.recurrence_type,
            recurrence_interval=payload.recurrence_interval,
            recurrence_unit=payload.recurrence_unit,
            created_by_id=current_user.id,
            version=1,
        )
        check.section = section
        db.add(check)
        db.flush()
        configure_control_schedule(check, payload)
        set_control_assignees(db, check, payload.assignee_ids)
        db.flush()
        check = get_control_check(db, check.id)
        return (
            SyncOperationResult(
                operation_id=operation.operation_id,
                status="APPLIED",
                control_check=check_read(check),
            ),
            "control.check.created",
        )

    check = get_control_check(db, operation.entity_id)
    if check.version != operation.base_version:
        return (
            _control_check_conflict(
                operation,
                check,
                (
                    "El control cambio en otro dispositivo. "
                    f"Version local {operation.base_version}; "
                    f"version servidor {check.version}."
                ),
            ),
            None,
        )

    if operation.operation_type == "UPDATE_CONTROL_CHECK":
        require_control_check_edit(current_user, check)
        update_control_check_from_payload(
            db,
            check,
            ControlCheckUpdate.model_validate(operation.payload),
        )
        event = "control.check.updated"
    elif operation.operation_type == "COMPLETE_CONTROL_CHECK":
        require_control_check_work(current_user, check)
        payload = ControlCheckComplete.model_validate(operation.payload)
        complete_control_check(check, current_user, notes=payload.notes)
        event = "control.check.completed"
    elif operation.operation_type == "REOPEN_CONTROL_CHECK":
        require_control_check_work(current_user, check)
        reopen_control_check(check)
        event = "control.check.reopened"
    elif operation.operation_type == "DELETE_CONTROL_CHECK":
        require_control_check_edit(current_user, check)
        deleted_id = check.id
        db.delete(check)
        db.flush()
        return (
            SyncOperationResult(
                operation_id=operation.operation_id,
                status="APPLIED",
                deleted_entity_id=deleted_id,
            ),
            "control.check.deleted",
        )
    else:
        raise ValueError(f"Operacion no soportada: {operation.operation_type}")

    db.add(check)
    db.flush()
    check = get_control_check(db, check.id)
    return (
        SyncOperationResult(
            operation_id=operation.operation_id,
            status="APPLIED",
            control_check=check_read(check),
        ),
        event,
    )


def _process_operation(
    operation: SyncOperation,
    db: Session,
    current_user: User,
) -> tuple[SyncOperationResult, str | None, str | None, UUID | None, bool]:
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
                None,
                True,
            )
        return _stored_result(existing), None, None, None, True

    if operation.operation_type in CONTROL_SECTION_OPERATION_TYPES:
        result, control_event = _apply_control_section_operation(
            operation, db, current_user
        )
        return result, control_event, None, None, False
    if operation.operation_type in CONTROL_CHECK_OPERATION_TYPES:
        result, control_event = _apply_control_check_operation(
            operation, db, current_user
        )
        return result, control_event, None, None, False
    if operation.operation_type == "CREATE_TASK":
        result, event, notification_event, checklist_id = _apply_create(
            operation, db, current_user
        )
    elif operation.operation_type == "UPDATE_TASK":
        result, event, notification_event, checklist_id = _apply_update(
            operation, db, current_user
        )
    elif operation.operation_type in CHECKLIST_OPERATION_TYPES:
        result, event, notification_event, checklist_id = _apply_checklist_operation(
            operation, db, current_user
        )
    else:
        result, event, notification_event, checklist_id = _apply_transition(
            operation,
            db,
            current_user,
        )
    return result, event, notification_event, checklist_id, False


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
        checklist_id: UUID | None = None
        try:
            (
                result,
                event,
                notification_event,
                checklist_id,
                already_stored,
            ) = _process_operation(operation, db, current_user)
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
            checklist_id = None

        if event is not None and result.control_section is not None:
            await manager.broadcast(
                {
                    "event": event,
                    "section_id": str(result.control_section.id),
                    "department_id": str(result.control_section.department.id),
                    "version": result.control_section.version,
                }
            )
        elif event is not None and result.control_check is not None:
            await manager.broadcast(
                {
                    "event": event,
                    "check_id": str(result.control_check.id),
                    "section_id": str(result.control_check.section_id),
                    "version": result.control_check.version,
                }
            )
        elif event is not None and result.deleted_entity_id is not None:
            await manager.broadcast(
                {
                    "event": event,
                    "check_id": str(result.deleted_entity_id),
                }
            )
        elif event is not None and result.task is not None:
            await manager.broadcast(
                {
                    "event": event,
                    "task_id": str(result.task.id),
                    "department_id": str(result.task.department.id),
                    "version": result.task.version,
                }
            )

        if notification_event is not None and result.task is not None:
            if notification_event == "checklist_completed" and checklist_id is not None:
                background_tasks.add_task(
                    notification_service.notify_checklist_completed,
                    task_id=result.task.id,
                    checklist_id=checklist_id,
                    actor_id=current_user.id,
                )
            else:
                schedule_task_notification(
                    background_tasks,
                    event_type=notification_event,
                    task_id=result.task.id,
                    actor_id=current_user.id,
                )

    return SyncResponse(results=results)
