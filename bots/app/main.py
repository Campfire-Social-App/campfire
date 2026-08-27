import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api import commands
from app.bots.ytdlp.bot import YtDlpBot
from app.campfire.client import CampfireClient
from app.campfire.gateway import GatewayConnection
from app.core.config import get_settings
from app.core.registry import Registry

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def build_registry() -> tuple[Registry, list[CampfireClient]]:
    """Wires up every bot this service hosts. One entry today; a second bot is
    another `registry.register(...)` here, and nothing else changes.

    Without credentials the service still starts, but hosts no bots: the command
    list comes back empty, which the clients already treat as "this deployment
    has no bots" and simply never show the `/` menu for. That is deliberate — a
    new, optional service must not be able to fail a deploy of the chat and the
    voice, and an operator who has not written the secrets yet gets a running
    stack plus a log line rather than a red pipeline.
    """
    settings = get_settings()
    registry = Registry()

    missing = [
        name
        for name, value in (
            ("BOT_PASSWORD", settings.bot_password),
            ("BOTS_SHARED_SECRET", settings.bots_shared_secret),
        )
        if not value
    ]
    if missing:
        logger.warning(
            "No bots will run: %s not set. Add them to the .env and restart to enable them.",
            " and ".join(missing),
        )
        return registry, []

    client = CampfireClient(
        base_url=settings.campfire_api_url,
        username=settings.bot_username,
        password=settings.bot_password,
    )
    registry.register(
        YtDlpBot(
            client=client,
            gateway=GatewayConnection(url=settings.campfire_gateway_url, client=client),
            ffmpeg_path=settings.ffmpeg_path,
            livekit_url_override=settings.livekit_url_override,
            bitrate=settings.music_bitrate,
            player_clients=settings.ytdlp_player_clients,
            cookies_file=settings.ytdlp_cookies_file,
            pot_base_url=settings.ytdlp_pot_base_url,
            proxy=settings.ytdlp_proxy,
        )
    )
    return registry, [client]


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    registry, clients = build_registry()
    app.state.registry = registry
    try:
        # Signing in and opening the gateway is what puts the bot in the member
        # list as online. A core server that isn't up yet must not kill this
        # process: the gateway retries on its own, and the first command will
        # sign in if boot could not.
        await registry.start_all()
    except Exception:
        logger.warning("Could not sign the bots in at boot; will retry", exc_info=True)

    try:
        yield
    finally:
        await registry.stop_all()
        for client in clients:
            await client.aclose()


def create_app() -> FastAPI:
    app = FastAPI(title="Campfire Bots", version="0.1.0", lifespan=lifespan)
    # Replaced by the lifespan with the wired-up one; this keeps /commands
    # answering (with nothing) if the app is mounted without a lifespan.
    app.state.registry = Registry()

    @app.get("/health")
    async def health() -> dict[str, str]:
        return {"status": "ok"}

    app.include_router(commands.router)
    return app


app = create_app()
