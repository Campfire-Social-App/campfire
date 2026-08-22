from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # App
    environment: str = "development"
    # tauri://localhost -> macOS/Linux Tauri webview origin.
    # http://tauri.localhost -> Windows/Android Tauri webview origin (WebView2/
    # Android WebView can't use custom schemes directly, so Tauri falls back to
    # this http://<scheme>.localhost form there — see tauri-apps/tauri
    # crates/tauri/src/manager/mod.rs `tauri_protocol_url`).
    # http://localhost:1420 -> `npm run dev` / `tauri dev`.
    # http://localhost:1421 -> `flutter run -d chrome --web-port 1421`, the web
    # build of the Flutter client, used to compare layout against the React one
    # side by side (PLANO_FLUTTER.md §10).
    cors_origins: list[str] = [
        "tauri://localhost",
        "http://tauri.localhost",
        "http://localhost:1420",
        "http://127.0.0.1:1420",
        "http://localhost:1421",
        "http://127.0.0.1:1421",
    ]

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
    livekit_api_secret: str = "324a9697e5bbde9de2844644ac03966ceab4bf67"


@lru_cache
def get_settings() -> Settings:
    return Settings()
