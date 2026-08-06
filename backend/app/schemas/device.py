from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

RegistrationKind = Literal["TOKEN", "FID"]
DevicePlatform = Literal["android", "ios", "web", "unknown"]


class DeviceRegistrationUpsert(BaseModel):
    registration_id: str = Field(min_length=20, max_length=4096)
    registration_kind: RegistrationKind = "TOKEN"
    platform: DevicePlatform = "unknown"
    device_name: str | None = Field(default=None, max_length=120)

    model_config = ConfigDict(extra="forbid")

    @field_validator("registration_id")
    @classmethod
    def normalize_registration_id(cls, value: str) -> str:
        normalized = value.strip()
        if len(normalized) < 20:
            raise ValueError("Identificador de registro no valido")
        return normalized

    @field_validator("device_name")
    @classmethod
    def normalize_device_name(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = " ".join(value.split())
        return normalized or None


class DeviceRegistrationDelete(BaseModel):
    registration_id: str = Field(min_length=20, max_length=4096)

    model_config = ConfigDict(extra="forbid")

    @field_validator("registration_id")
    @classmethod
    def normalize_registration_id(cls, value: str) -> str:
        return value.strip()


class DeviceRegistrationRead(BaseModel):
    id: UUID
    registration_kind: RegistrationKind
    platform: DevicePlatform
    device_name: str | None
    is_active: bool
    created_at: datetime
    updated_at: datetime
    last_seen_at: datetime
    last_success_at: datetime | None

    model_config = ConfigDict(from_attributes=True)


class DeviceRegistrationSummary(BaseModel):
    active_count: int
    registrations: list[DeviceRegistrationRead]
