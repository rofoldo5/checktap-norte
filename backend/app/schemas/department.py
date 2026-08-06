from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.user import UserSummary


class DepartmentCreate(BaseModel):
    name: str = Field(min_length=2, max_length=120)

    @field_validator("name")
    @classmethod
    def normalize_name(cls, value: str) -> str:
        normalized = " ".join(value.split())
        if len(normalized) < 2:
            raise ValueError("Ingrese un nombre de departamento valido")
        return normalized


class DepartmentUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=120)
    is_active: bool | None = None

    @field_validator("name")
    @classmethod
    def normalize_optional_name(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = " ".join(value.split())
        if len(normalized) < 2:
            raise ValueError("Ingrese un nombre de departamento valido")
        return normalized


class DepartmentMembersUpdate(BaseModel):
    user_ids: list[UUID] = Field(default_factory=list, max_length=500)


class DepartmentSummary(BaseModel):
    id: UUID
    name: str
    is_active: bool
    member_count: int = 0

    model_config = ConfigDict(from_attributes=True)


class DepartmentRead(DepartmentSummary):
    members: list[UserSummary] = Field(default_factory=list)
    created_at: datetime
    updated_at: datetime
