from functools import lru_cache

from pydantic import field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "CheckTap"
    app_version: str = "0.13.0"
    environment: str = "development"
    api_prefix: str = "/api/v1"

    database_url: str = "sqlite+pysqlite:///./checktap.db"

    jwt_secret: str = "development-secret-change-this-1234567890"
    jwt_algorithm: str = "HS256"
    access_token_minutes: int = 480

    cors_origins: str = "*"

    bootstrap_admin_name: str = "Administrador"
    bootstrap_admin_email: str = "admin@checktap.com"
    bootstrap_admin_password: str = "Admin123!"

    default_department_name: str = "Programacion"
    self_registration_enabled: bool = True

    report_timezone: str = "America/Montreal"
    report_storage_path: str = "/app/reports"
    daily_report_enabled: bool = True
    daily_report_time: str = "17:00"
    scheduler_poll_seconds: int = 60

    firebase_enabled: bool = False
    firebase_android_channel_id: str = "checktap_high_importance"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    @field_validator("default_department_name")
    @classmethod
    def validate_default_department_name(cls, value: str) -> str:
        normalized = " ".join(value.split())
        if len(normalized) < 2:
            raise ValueError("DEFAULT_DEPARTMENT_NAME no es valido")
        return normalized

    @field_validator("daily_report_time")
    @classmethod
    def validate_daily_report_time(cls, value: str) -> str:
        parts = value.split(":")
        if len(parts) != 2:
            raise ValueError("DAILY_REPORT_TIME debe usar HH:MM")
        hour, minute = (int(part) for part in parts)
        if not 0 <= hour <= 23 or not 0 <= minute <= 59:
            raise ValueError("DAILY_REPORT_TIME debe usar HH:MM")
        return f"{hour:02d}:{minute:02d}"

    @model_validator(mode="after")
    def validate_production_settings(self) -> "Settings":
        if self.environment.lower() != "production":
            return self

        if self.database_url.startswith("sqlite"):
            raise ValueError("Production requires PostgreSQL DATABASE_URL")
        if len(self.jwt_secret) < 32 or self.jwt_secret.startswith(
            "development-secret"
        ):
            raise ValueError("Production requires a strong JWT_SECRET")
        if self.bootstrap_admin_password == "Admin123!":
            raise ValueError("Production requires a strong bootstrap admin password")
        return self

    @property
    def cors_origins_list(self) -> list[str]:
        return [item.strip() for item in self.cors_origins.split(",") if item.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
