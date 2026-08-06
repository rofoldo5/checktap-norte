from uuid import UUID

from pydantic import BaseModel


class NotificationStatus(BaseModel):
    enabled: bool
    initialized: bool
    project_id: str | None
    error: str | None
    active_registrations: int


class DepartmentNotificationTest(BaseModel):
    department_id: UUID | None = None


class NotificationSendResult(BaseModel):
    attempted: int
    success_count: int
    failure_count: int
    deactivated_count: int
    message_ids: list[str]
    event_id: UUID | None = None
