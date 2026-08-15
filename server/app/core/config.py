from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # App
    environment: str = "development"
    cors_origins: list[str] = ["tauri://localhost", "http://localhost:1420"]

    # Database
    database_url: str = "postgresql+asyncpg://campfire:campfire@localhost:5432/campfire"

    # JWT
    jwt_secret: str = "change-me-in-production-min-32-bytes-long"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 15
    refresh_token_expire_days: int = 30

    # First admin bootstrap
    first_admin_username: str | None = None
    first_admin_password: str | None = None

    # Uploads
    upload_dir: str = "./uploads"
    max_upload_bytes: int = 25 * 1024 * 1024

    # LiveKit
    livekit_url: str = "ws://localhost:7880"
    livekit_api_key: str = "devkey"
    livekit_api_secret: str = "devsecret1234567890devsecret"


@lru_cache
def get_settings() -> Settings:
    return Settings()
