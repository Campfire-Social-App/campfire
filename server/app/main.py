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
from app.gateway.router import router as gateway_router
from app.services.bootstrap import ensure_admin


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    settings = get_settings()
    Path(settings.upload_dir).mkdir(parents=True, exist_ok=True)

    if settings.first_admin_username and settings.first_admin_password:
        async with async_session_maker() as db:
            await ensure_admin(db, settings.first_admin_username, settings.first_admin_password)

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
