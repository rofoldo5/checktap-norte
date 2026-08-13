from datetime import datetime
from typing import Literal
from uuid import UUID
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.schemas.department import DepartmentSummary
from app.schemas.user import UserSummary

ControlPriority = Literal["BAJA", "MEDIA", "ALTA"]
ControlStatus = Literal["PENDIENTE", "COMPLETADA"]
ControlDueState = Literal["VIGENTE", "PROXIMA", "URGENTE", "VENCIDA", "COMPLETADA"]
ControlRecurrenceType = Literal[
    "NONE",
    "DAILY",
    "WEEKLY",
    "MONTHLY",
    "YEARLY",
    "CUSTOM",
]
ControlRecurrenceUnit = Literal["DAYS", "WEEKS", "MONTHS", "YEARS"]


class ControlSectionCreate(BaseModel):
    id: UUID | None = None
    name: str = Field(min_length=2, max_length=120)
    description: str | None = Field(default=None, max_length=2000)
    icon_key: str = Field(default="folder", min_length=1, max_length=40)
    department_id: UUID | None = None

    model_config = ConfigDict(extra="forbid")

    @field_validator("name")
    @classmethod
    def normalize_name(cls, value: str) -> str:
        normalized = " ".join(value.split())
        if len(normalized) < 2:
            raise ValueError("Ingrese un nombre valido")
        return normalized

    @field_validator("description")
    @classmethod
    def normalize_description(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = value.strip()
        return normalized or None

    @field_validator("icon_key")
    @classmethod
    def normalize_icon(cls, value: str) -> str:
        return value.strip().lower() or "folder"


class ControlSectionUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=120)
    description: str | None = Field(default=None, max_length=2000)
    icon_key: str | None = Field(default=None, min_length=1, max_length=40)
    department_id: UUID | None = None
    is_active: bool | None = None

    model_config = ConfigDict(extra="forbid")

    @field_validator("name")
    @classmethod
    def normalize_optional_name(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = " ".join(value.split())
        if len(normalized) < 2:
            raise ValueError("Ingrese un nombre valido")
        return normalized

    @field_validator("description")
    @classmethod
    def normalize_optional_description(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return value.strip() or None

    @field_validator("icon_key")
    @classmethod
    def normalize_optional_icon(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return value.strip().lower() or "folder"

    @model_validator(mode="after")
    def reject_invalid_nulls(self):
        for field in ("name", "department_id", "is_active"):
            if field in self.model_fields_set and getattr(self, field) is None:
                raise ValueError(f"El campo {field} no puede ser nulo")
        return self


class ControlSectionRead(BaseModel):
    id: UUID
    name: str
    description: str | None
    icon_key: str
    department: DepartmentSummary
    created_by: UserSummary
    is_active: bool
    version: int
    created_at: datetime
    updated_at: datetime
    check_count: int = 0
    upcoming_count: int = 0
    urgent_count: int = 0
    overdue_count: int = 0
    completed_count: int = 0

    model_config = ConfigDict(from_attributes=True)


class ControlCheckHistoryRead(BaseModel):
    id: UUID
    due_at: datetime
    completed_at: datetime
    next_due_at: datetime | None
    completion_notes: str | None = None
    completed_by: UserSummary | None = None

    model_config = ConfigDict(from_attributes=True)


class _ControlScheduleFields(BaseModel):
    due_at: datetime
    timezone: str = Field(default="UTC", min_length=1, max_length=80)
    reminder_minutes: list[int] = Field(default_factory=list, max_length=20)
    recurrence_type: ControlRecurrenceType = "NONE"
    recurrence_interval: int = Field(default=1, ge=1, le=365)
    recurrence_unit: ControlRecurrenceUnit | None = None

    @field_validator("timezone")
    @classmethod
    def validate_timezone(cls, value: str) -> str:
        normalized = value.strip() or "UTC"
        try:
            ZoneInfo(normalized)
        except ZoneInfoNotFoundError as exc:
            raise ValueError("La zona horaria no es valida") from exc
        return normalized

    @field_validator("reminder_minutes")
    @classmethod
    def normalize_reminders(cls, values: list[int]) -> list[int]:
        normalized = sorted({int(value) for value in values if int(value) >= 0}, reverse=True)
        if len(normalized) > 20:
            raise ValueError("Solo se permiten hasta 20 recordatorios")
        if any(value > 525600 for value in normalized):
            raise ValueError("Un recordatorio no puede exceder 365 dias")
        return normalized

    @model_validator(mode="after")
    def normalize_recurrence(self):
        if self.recurrence_type == "NONE":
            self.recurrence_interval = 1
            self.recurrence_unit = None
        elif self.recurrence_type == "CUSTOM":
            if self.recurrence_unit is None:
                raise ValueError("Seleccione dias, semanas, meses o anos")
        else:
            self.recurrence_interval = 1
            self.recurrence_unit = None
        return self


class ControlCheckCreate(_ControlScheduleFields):
    id: UUID | None = None
    title: str = Field(min_length=2, max_length=180)
    description: str | None = Field(default=None, max_length=3000)
    reference: str | None = Field(default=None, max_length=300)
    contact: str | None = Field(default=None, max_length=300)
    notes: str | None = Field(default=None, max_length=5000)
    priority: ControlPriority = "MEDIA"
    assignee_ids: list[UUID] = Field(default_factory=list, max_length=100)

    model_config = ConfigDict(extra="forbid")

    @field_validator("title")
    @classmethod
    def normalize_title(cls, value: str) -> str:
        normalized = " ".join(value.split())
        if len(normalized) < 2:
            raise ValueError("Ingrese un nombre valido")
        return normalized

    @field_validator("description", "reference", "contact", "notes")
    @classmethod
    def normalize_optional_text(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return value.strip() or None

    @field_validator("assignee_ids")
    @classmethod
    def unique_assignees(cls, values: list[UUID]) -> list[UUID]:
        return list(dict.fromkeys(values))


class ControlCheckUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=2, max_length=180)
    description: str | None = Field(default=None, max_length=3000)
    reference: str | None = Field(default=None, max_length=300)
    contact: str | None = Field(default=None, max_length=300)
    notes: str | None = Field(default=None, max_length=5000)
    priority: ControlPriority | None = None
    due_at: datetime | None = None
    timezone: str | None = Field(default=None, min_length=1, max_length=80)
    reminder_minutes: list[int] | None = Field(default=None, max_length=20)
    recurrence_type: ControlRecurrenceType | None = None
    recurrence_interval: int | None = Field(default=None, ge=1, le=365)
    recurrence_unit: ControlRecurrenceUnit | None = None
    assignee_ids: list[UUID] | None = Field(default=None, max_length=100)

    model_config = ConfigDict(extra="forbid")

    @field_validator("title")
    @classmethod
    def normalize_optional_title(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = " ".join(value.split())
        if len(normalized) < 2:
            raise ValueError("Ingrese un nombre valido")
        return normalized

    @field_validator("description", "reference", "contact", "notes")
    @classmethod
    def normalize_optional_text(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return value.strip() or None

    @field_validator("timezone")
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

    @field_validator("reminder_minutes")
    @classmethod
    def normalize_optional_reminders(cls, values: list[int] | None) -> list[int] | None:
        if values is None:
            return None
        normalized = sorted({int(value) for value in values if int(value) >= 0}, reverse=True)
        if any(value > 525600 for value in normalized):
            raise ValueError("Un recordatorio no puede exceder 365 dias")
        return normalized

    @field_validator("assignee_ids")
    @classmethod
    def unique_optional_assignees(cls, values: list[UUID] | None) -> list[UUID] | None:
        return None if values is None else list(dict.fromkeys(values))

    @model_validator(mode="after")
    def reject_invalid_nulls(self):
        for field in ("title", "priority", "due_at", "timezone", "recurrence_type"):
            if field in self.model_fields_set and getattr(self, field) is None:
                raise ValueError(f"El campo {field} no puede ser nulo")
        return self


class ControlCheckComplete(BaseModel):
    notes: str | None = Field(default=None, max_length=2000)

    @field_validator("notes")
    @classmethod
    def normalize_notes(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return value.strip() or None


class ControlCheckRead(BaseModel):
    id: UUID
    section_id: UUID
    section_name: str
    title: str
    description: str | None
    reference: str | None
    contact: str | None
    notes: str | None
    priority: ControlPriority
    status: ControlStatus
    due_state: ControlDueState
    due_at: datetime
    timezone: str
    reminder_minutes: list[int] = Field(default_factory=list)
    next_reminder_at: datetime | None = None
    recurrence_type: ControlRecurrenceType
    recurrence_interval: int
    recurrence_unit: ControlRecurrenceUnit | None
    version: int
    created_by: UserSummary
    assignees: list[UserSummary] = Field(default_factory=list)
    completed_by: UserSummary | None
    completed_at: datetime | None
    created_at: datetime
    updated_at: datetime
    history: list[ControlCheckHistoryRead] = Field(default_factory=list)


class ControlSnapshot(BaseModel):
    sections: list[ControlSectionRead] = Field(default_factory=list)
    checks: list[ControlCheckRead] = Field(default_factory=list)
