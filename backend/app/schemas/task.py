from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.schemas.department import DepartmentSummary
from app.schemas.user import UserSummary

TaskStatus = Literal["PENDIENTE", "EN_PROGRESO", "COMPLETADA"]
TaskPriority = Literal["BAJA", "MEDIA", "ALTA"]


class TaskCreate(BaseModel):
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
    def normalize_assignees(self):
        unique = list(dict.fromkeys(self.assignee_ids))
        if self.assigned_to_id is not None and self.assigned_to_id not in unique:
            unique.insert(0, self.assigned_to_id)
        self.assignee_ids = unique
        return self


class TaskUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=2, max_length=150)
    description: str | None = Field(default=None, max_length=3000)
    priority: TaskPriority | None = None
    department_id: UUID | None = None
    assignee_ids: list[UUID] | None = Field(default=None, max_length=100)
    assigned_to_id: UUID | None = None

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

    model_config = ConfigDict(from_attributes=True)
