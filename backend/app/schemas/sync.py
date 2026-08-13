from typing import Any, Literal
from uuid import UUID

from pydantic import BaseModel, Field

from app.schemas.control import ControlCheckRead, ControlSectionRead
from app.schemas.task import TaskRead

SyncOperationType = Literal[
    "CREATE_TASK",
    "UPDATE_TASK",
    "START_TASK",
    "COMPLETE_TASK",
    "REOPEN_TASK",
    "CREATE_CHECKLIST",
    "UPDATE_CHECKLIST",
    "DELETE_CHECKLIST",
    "CREATE_CHECKLIST_ITEM",
    "UPDATE_CHECKLIST_ITEM",
    "DELETE_CHECKLIST_ITEM",
    "SET_CHECKLIST_ITEM_STATE",
    "SET_CHECKLIST_STATE",
    "CREATE_CONTROL_SECTION",
    "UPDATE_CONTROL_SECTION",
    "ARCHIVE_CONTROL_SECTION",
    "CREATE_CONTROL_CHECK",
    "UPDATE_CONTROL_CHECK",
    "COMPLETE_CONTROL_CHECK",
    "REOPEN_CONTROL_CHECK",
    "DELETE_CONTROL_CHECK",
]
SyncResultStatus = Literal["APPLIED", "DUPLICATE", "CONFLICT", "ERROR"]


class SyncOperation(BaseModel):
    operation_id: UUID
    operation_type: SyncOperationType
    entity_id: UUID
    base_version: int = Field(default=0, ge=0)
    payload: dict[str, Any] = Field(default_factory=dict)


class SyncRequest(BaseModel):
    operations: list[SyncOperation] = Field(min_length=1, max_length=50)


class SyncOperationResult(BaseModel):
    operation_id: UUID
    status: SyncResultStatus
    detail: str | None = None
    task: TaskRead | None = None
    control_section: ControlSectionRead | None = None
    control_check: ControlCheckRead | None = None
    deleted_entity_id: UUID | None = None


class SyncResponse(BaseModel):
    results: list[SyncOperationResult]
