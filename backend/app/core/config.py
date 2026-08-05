from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "CheckTap"
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

    report_timezone: str = "America/Montreal"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    @property
    def cors_origins_list(self) -> list[str]:
        return [
            item.strip()
            for item in self.cors_origins.split(",")
            if item.strip()
        ]


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
