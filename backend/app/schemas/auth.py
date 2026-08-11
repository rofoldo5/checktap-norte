from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from app.schemas.device import DeviceRegistrationUpsert
from app.schemas.user import UserRead


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6, max_length=128)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserRead


class RegistrationDepartment(BaseModel):
    id: UUID
    name: str

    model_config = ConfigDict(from_attributes=True)


class RegistrationRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str = Field(min_length=2, max_length=120)
    email: EmailStr
    password: str = Field(min_length=6, max_length=128)
    department_id: UUID
    device_registration: DeviceRegistrationUpsert | None = None

    @field_validator("name")
    @classmethod
    def normalize_name(cls, value: str) -> str:
        normalized = " ".join(value.split())
        if len(normalized) < 2:
            raise ValueError("Ingrese un nombre valido")
        return normalized

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: EmailStr) -> str:
        return str(value).strip().lower()

    @field_validator("password")
    @classmethod
    def validate_password(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("La contrasena no puede contener solo espacios")
        return value


class RegistrationResponse(BaseModel):
    id: UUID
    name: str
    email: EmailStr
    account_status: str
    department_id: UUID
    notification_registered: bool = False
    message: str
