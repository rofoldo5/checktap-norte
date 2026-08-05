from typing import Any, Literal
from uuid import UUID

from pydantic import BaseModel, Field

from app.schemas.task import TaskRead

SyncOperationType = Literal[
    "CREATE_TASK",
    "UPDATE_TASK",
    "START_TASK",
    "COMPLETE_TASK",
    "REOPEN_TASK",
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


class SyncResponse(BaseModel):
    results: list[SyncOperationResult]
