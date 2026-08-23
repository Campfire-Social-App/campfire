import logging
import uuid
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import (
    auth,
    channels,
    dms,
    invites,
    messages,
    server,
    uploads,
    users,
    voice,
    webhooks,
)
from app.core.config import get_settings
from app.db import async_session_maker
from app.gateway.manager import VoiceParticipantState, manager
from app.gateway.router import router as gateway_router
from app.services.bootstrap import ensure_admin
from app.services.livekit_service import list_active_participants

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    settings = get_settings()
    Path(settings.upload_dir).mkdir(parents=True, exist_ok=True)

    if settings.first_admin_username and settings.first_admin_password:
        async with async_session_maker() as db:
            await ensure_admin(db, settings.first_admin_username, settings.first_admin_password)

    # Voice presence is ephemeral, but LiveKit may outlive an API restart. Rebuild
    # the in-memory index so moderation and channel rosters keep working without
    # requiring everyone to leave and rejoin their calls.
    try:
        manager.voice_state.clear()
        for identity, username, room, muted, deafened in await list_active_participants():
            try:
                user_id = uuid.UUID(identity)
                channel_id = uuid.UUID(room)
            except ValueError:
                continue
            manager.voice_state[user_id] = VoiceParticipantState(
                user_id=user_id,
                channel_id=channel_id,
                username=username,
                muted=muted,
                deafened=deafened,
            )
    except Exception:
        logger.warning("Could not restore voice state from LiveKit", exc_info=True)

    yield


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(title="Campfire", version="0.1.0", lifespan=lifespan)

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
        # A <video>/<audio> element loaded in CORS mode (which is what the
        # Flutter web player does) streams by byte range, and the browser
        # rejects the media as a "format error" unless these come back readable
        # to script. The Tauri webview never hits this: it loads media without
        # crossorigin, so no CORS response is involved at all.
        expose_headers=["Content-Range", "Accept-Ranges", "Content-Length", "Content-Disposition"],
    )

    @app.get("/health")
    async def health() -> dict[str, str]:
        return {"status": "ok"}

    app.include_router(auth.router)
    app.include_router(invites.router)
    app.include_router(server.router)
    app.include_router(users.router)
    app.include_router(channels.router)
    app.include_router(messages.router)
    app.include_router(dms.router)
    app.include_router(uploads.router)
    app.include_router(voice.router)
    app.include_router(webhooks.router)
    app.include_router(gateway_router)

    Path(settings.upload_dir).mkdir(parents=True, exist_ok=True)

    return app


app = create_app()
