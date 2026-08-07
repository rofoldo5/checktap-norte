from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.user import UserSummary


def _normalize_text(value: str, *, minimum: int = 2) -> str:
    normalized = " ".join(value.split())
    if len(normalized) < minimum:
        raise ValueError("Ingrese un texto valido")
    return normalized


class ChecklistItemSeed(BaseModel):
    id: UUID | None = None
    title: str = Field(min_length=2, max_length=300)
    position: int | None = Field(default=None, ge=0)

    @field_validator("title")
    @classmethod
    def validate_title(cls, value: str) -> str:
        return _normalize_text(value)


class ChecklistCreate(BaseModel):
    id: UUID | None = None
    title: str = Field(min_length=2, max_length=180)
    position: int | None = Field(default=None, ge=0)
    items: list[ChecklistItemSeed] = Field(default_factory=list, max_length=200)

    @field_validator("title")
    @classmethod
    def validate_title(cls, value: str) -> str:
        return _normalize_text(value)


class ChecklistUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=2, max_length=180)
    position: int | None = Field(default=None, ge=0)

    @field_validator("title")
    @classmethod
    def validate_title(cls, value: str | None) -> str | None:
        return None if value is None else _normalize_text(value)


class ChecklistItemCreate(BaseModel):
    id: UUID | None = None
    title: str = Field(min_length=2, max_length=300)
    position: int | None = Field(default=None, ge=0)

    @field_validator("title")
    @classmethod
    def validate_title(cls, value: str) -> str:
        return _normalize_text(value)


class ChecklistItemUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=2, max_length=300)
    position: int | None = Field(default=None, ge=0)

    @field_validator("title")
    @classmethod
    def validate_title(cls, value: str | None) -> str | None:
        return None if value is None else _normalize_text(value)


class ChecklistSetCompleted(BaseModel):
    is_completed: bool


class ChecklistItemRead(BaseModel):
    id: UUID
    title: str
    position: int
    is_completed: bool
    version: int
    created_by: UserSummary
    completed_by: UserSummary | None
    created_at: datetime
    updated_at: datetime
    completed_at: datetime | None

    model_config = ConfigDict(from_attributes=True)


class ChecklistRead(BaseModel):
    id: UUID
    title: str
    position: int
    version: int
    created_by: UserSummary
    created_at: datetime
    updated_at: datetime
    item_count: int
    completed_count: int
    is_completed: bool
    items: list[ChecklistItemRead] = Field(default_factory=list)

    model_config = ConfigDict(from_attributes=True)
