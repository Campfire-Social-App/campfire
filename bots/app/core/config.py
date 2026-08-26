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

    # Opus bitrate for the published music track, in bits per second. The
    # default is LiveKit's own "music high quality stereo" figure; it is what
    # makes the SFU negotiate a stereo stream instead of the mono speech preset
    # a microphone track gets by default. Turn it down on a thin uplink — the
    # SFU sends one stream per listener.
    music_bitrate: int = 128_000

    # Comma-separated yt-dlp YouTube player clients, tried in order. Empty
    # leaves yt-dlp's own default, which is the best-tested path. Worth setting
    # when YouTube answers "Sign in to confirm you're not a bot" — that check
    # is applied per source IP, and a datacenter address trips it far more
    # readily than a home one. Clients that need no PO token for the media URL
    # itself: tv, tv_downgraded, web_embedded, visionos.
    ytdlp_player_clients: str = ""

    # Path to a Netscape-format cookies file, mounted into the container. The
    # dependable answer to the same block, at the cost of tying a Google
    # account to the bot — use a throwaway, never a personal one.
    ytdlp_cookies_file: str = ""

    # Where ffmpeg is; overridable so a dev box can run this outside Docker.
    ffmpeg_path: str = "ffmpeg"


@lru_cache
def get_settings() -> Settings:
    return Settings()
