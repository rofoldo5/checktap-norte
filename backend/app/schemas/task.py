from datetime import datetime
from typing import Literal
from uuid import UUID
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.schemas.checklist import ChecklistRead
from app.schemas.department import DepartmentSummary
from app.schemas.user import UserSummary

TaskStatus = Literal["PENDIENTE", "EN_PROGRESO", "COMPLETADA"]
TaskPriority = Literal["BAJA", "MEDIA", "ALTA"]
TaskRecurrenceType = Literal["NONE", "DAILY", "WEEKLY", "MONTHLY", "CUSTOM"]
TaskRecurrenceUnit = Literal["DAYS", "WEEKS", "MONTHS"]


class _RecurrenceFields(BaseModel):
    recurrence_type: TaskRecurrenceType = "NONE"
    recurrence_interval: int = Field(default=1, ge=1, le=365)
    recurrence_unit: TaskRecurrenceUnit | None = None
    recurrence_start_at: datetime | None = None
    recurrence_timezone: str = Field(default="UTC", min_length=1, max_length=80)
    notifications_enabled: bool = False
    reminder_minutes_before: int = Field(default=0, ge=0, le=10080)

    @field_validator("recurrence_timezone")
    @classmethod
    def validate_timezone(cls, value: str) -> str:
        normalized = value.strip() or "UTC"
        try:
            ZoneInfo(normalized)
        except ZoneInfoNotFoundError as exc:
            raise ValueError("La zona horaria no es valida") from exc
        return normalized


class TaskCreate(_RecurrenceFields):
    id: UUID | None = None
    title: str = Field(min_length=2, max_length=150)
    description: str | None = Field(default=None, max_length=3000)
    priority: TaskPriority = "MEDIA"
    department_id: UUID | None = None
    assignee_ids: list[UUID] = Field(default_factory=list, max_length=100)
    assigned_to_id: UUID | None = None

    model_config = ConfigDict(extra="forbid")

    @field_validator("title")
    @classmethod
    def validate_title(cls, value: str) -> str:
        normalized = " ".join(value.split())
        if len(normalized) < 2:
            raise ValueError("Ingrese un titulo valido")
        return normalized

    @field_validator("description")
    @classmethod
    def normalize_description(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = value.strip()
        return normalized or None

    @model_validator(mode="after")
    def normalize_task(self):
        unique = list(dict.fromkeys(self.assignee_ids))
        if self.assigned_to_id is not None and self.assigned_to_id not in unique:
            unique.insert(0, self.assigned_to_id)
        self.assignee_ids = unique

        if self.recurrence_type == "NONE":
            self.recurrence_interval = 1
            self.recurrence_unit = None
            self.recurrence_start_at = None
            self.notifications_enabled = False
            self.reminder_minutes_before = 0
        else:
            if self.recurrence_start_at is None:
                raise ValueError("Seleccione la fecha y hora de inicio")
            if self.recurrence_type == "CUSTOM":
                if self.recurrence_unit is None:
                    raise ValueError("Seleccione dias, semanas o meses")
            else:
                self.recurrence_interval = 1
                self.recurrence_unit = None
        return self


class TaskUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=2, max_length=150)
    description: str | None = Field(default=None, max_length=3000)
    priority: TaskPriority | None = None
    department_id: UUID | None = None
    assignee_ids: list[UUID] | None = Field(default=None, max_length=100)
    assigned_to_id: UUID | None = None

    recurrence_type: TaskRecurrenceType | None = None
    recurrence_interval: int | None = Field(default=None, ge=1, le=365)
    recurrence_unit: TaskRecurrenceUnit | None = None
    recurrence_start_at: datetime | None = None
    recurrence_timezone: str | None = Field(default=None, min_length=1, max_length=80)
    notifications_enabled: bool | None = None
    reminder_minutes_before: int | None = Field(default=None, ge=0, le=10080)

    model_config = ConfigDict(extra="forbid")

    @field_validator("title")
    @classmethod
    def validate_optional_title(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = " ".join(value.split())
        if len(normalized) < 2:
            raise ValueError("Ingrese un titulo valido")
        return normalized

    @field_validator("description")
    @classmethod
    def normalize_optional_description(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = value.strip()
        return normalized or None

    @field_validator("recurrence_timezone")
    @classmethod
    def validate_optional_timezone(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = value.strip() or "UTC"
        try:
            ZoneInfo(normalized)
        except ZoneInfoNotFoundError as exc:
            raise ValueError("La zona horaria no es valida") from exc
        return normalized

    @model_validator(mode="after")
    def normalize_and_reject_invalid_nulls(self):
        for field in ("title", "priority", "department_id"):
            if field in self.model_fields_set and getattr(self, field) is None:
                raise ValueError(f"El campo {field} no puede ser nulo")
        if self.assignee_ids is not None:
            self.assignee_ids = list(dict.fromkeys(self.assignee_ids))
        if "assigned_to_id" in self.model_fields_set:
            if self.assignee_ids is None:
                self.assignee_ids = []
            if (
                self.assigned_to_id is not None
                and self.assigned_to_id not in self.assignee_ids
            ):
                self.assignee_ids.insert(0, self.assigned_to_id)
        return self


class TaskRead(BaseModel):
    id: UUID
    title: str
    description: str | None
    status: TaskStatus
    priority: TaskPriority
    version: int
    department: DepartmentSummary
    created_by: UserSummary
    assignees: list[UserSummary] = Field(default_factory=list)
    assigned_to: UserSummary | None
    completed_by: UserSummary | None
    created_at: datetime
    updated_at: datetime
    completed_at: datetime | None
    checklists: list[ChecklistRead] = Field(default_factory=list)

    recurrence_type: TaskRecurrenceType = "NONE"
    recurrence_interval: int = 1
    recurrence_unit: TaskRecurrenceUnit | None = None
    recurrence_start_at: datetime | None = None
    recurrence_timezone: str = "UTC"
    next_occurrence_at: datetime | None = None
    notifications_enabled: bool = False
    reminder_minutes_before: int = 0
    recurrence_series_id: str | None = None
    is_recurrence_master: bool = False
    scheduled_for: datetime | None = None

    model_config = ConfigDict(from_attributes=True)
