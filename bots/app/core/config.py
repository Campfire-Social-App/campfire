from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    environment: str = "development"

    # The core server, reached over the compose network. This service is never
    # published by Caddy — commands arrive from the server, not from clients.
    campfire_api_url: str = "http://127.0.0.1:8000"
    campfire_gateway_url: str = "ws://127.0.0.1:8000/gateway"

    # The account the bot signs in as. Created on the server's side by
    # `ensure_bot` from the same values, so the .env is the single source.
    bot_username: str = "ytdlp"
    bot_password: str = ""

    # Proves a command really came from the core server.
    bots_shared_secret: str = ""

    # Overrides the LiveKit URL that /api/voice/{id}/token hands back. Only
    # needed when the public address is not routable from inside this container
    # (a VPS without hairpin NAT) — then point it at the SFU directly, e.g.
    # ws://livekit:7880.
    livekit_url_override: str = ""

    # Where ffmpeg is; overridable so a dev box can run this outside Docker.
    ffmpeg_path: str = "ffmpeg"


@lru_cache
def get_settings() -> Settings:
    return Settings()
