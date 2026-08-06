from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator, model_validator


class UserCreate(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    email: EmailStr
    password: str = Field(min_length=6, max_length=128)
    is_admin: bool = False
    department_ids: list[UUID] = Field(default_factory=list, max_length=50)

    @field_validator("name")
    @classmethod
    def validate_name(cls, value: str) -> str:
        normalized = " ".join(value.split())
        if len(normalized) < 2:
            raise ValueError("Ingrese un nombre valido")
        return normalized

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: EmailStr) -> str:
        return str(value).strip().lower()


class UserUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=120)
    password: str | None = Field(default=None, min_length=6, max_length=128)
    is_admin: bool | None = None
    is_active: bool | None = None
    department_ids: list[UUID] | None = Field(default=None, max_length=50)

    @field_validator("name")
    @classmethod
    def validate_optional_name(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = " ".join(value.split())
        if len(normalized) < 2:
            raise ValueError("Ingrese un nombre valido")
        return normalized

    @model_validator(mode="after")
    def reject_explicit_nulls(self):
        for field in ("name", "password", "is_admin", "is_active"):
            if field in self.model_fields_set and getattr(self, field) is None:
                raise ValueError(f"El campo {field} no puede ser nulo")
        return self


class UserSummary(BaseModel):
    id: UUID
    name: str
    email: EmailStr
    is_admin: bool = False
    is_active: bool = True
    department_ids: list[UUID] = Field(default_factory=list)

    model_config = ConfigDict(from_attributes=True)


class UserRead(UserSummary):
    created_at: datetime
