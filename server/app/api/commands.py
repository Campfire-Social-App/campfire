import logging
import time

import httpx
from fastapi import APIRouter, HTTPException, status

from app.core.config import get_settings
from app.core.deps import CurrentUser, DbSession, require_not_timed_out
from app.gateway.manager import manager
from app.schemas.command import RunCommandRequest, SlashCommand
from app.services.channel_access import readable_channel_or_404

router = APIRouter(prefix="/api/commands", tags=["commands"])
logger = logging.getLogger(__name__)

# The command list is static for as long as the bots service is running, and
# every client asks for it once per session — no reason to make that a network
# round trip each time.
_CACHE_TTL_SECONDS = 300
_cache: tuple[float, list[SlashCommand]] | None = None

# Generous enough for a bots service that is starting up, short enough that a
# wedged one doesn't hold the composer hostage.
_TIMEOUT = httpx.Timeout(10.0, connect=3.0)


def _bots_headers() -> dict[str, str]:
    return {"X-Campfire-Bot-Secret": get_settings().bots_shared_secret}


@router.get("", response_model=list[SlashCommand])
async def list_commands(_user: CurrentUser) -> list[SlashCommand]:
    """What the composer offers after a `/`.

    A deployment without a bots service, or one whose bots service is down, has
    no commands rather than an error: the popup simply never opens, and the rest
    of the app is unaffected.
    """
    global _cache
    settings = get_settings()
    if not settings.bots_url:
        return []

    if _cache is not None and time.monotonic() - _cache[0] < _CACHE_TTL_SECONDS:
        return _cache[1]

    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
            response = await client.get(
                f"{settings.bots_url.rstrip('/')}/commands", headers=_bots_headers()
            )
            response.raise_for_status()
            commands = [SlashCommand.model_validate(item) for item in response.json()]
    except Exception:
        logger.warning("Could not reach the bots service for the command list", exc_info=True)
        # Deliberately not cached: the next request should try again.
        return _cache[1] if _cache is not None else []

    _cache = (time.monotonic(), commands)
    return commands


@router.post("", status_code=status.HTTP_202_ACCEPTED)
async def run_command(
    payload: RunCommandRequest, user: CurrentUser, db: DbSession
) -> dict[str, bool]:
    """Hands a slash command to the bots service, with context it can trust.

    The caller says *what* to run and *where* they said it; who they are and
    which voice channel they're in come from this process, never from the
    request body — otherwise anyone could make the bot join a call they aren't
    in themselves.
    """
    require_not_timed_out(user)
    settings = get_settings()
    if not settings.bots_url:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="This server has no bots configured",
        )

    channel = await readable_channel_or_404(payload.channel_id, user, db)
    voice_state = manager.voice_state.get(user.id)

    body = {
        "user": {"id": str(user.id), "username": user.username},
        "text_channel_id": str(channel.id),
        "voice_channel_id": str(voice_state.channel_id) if voice_state else None,
        "args": payload.args,
    }

    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
            response = await client.post(
                f"{settings.bots_url.rstrip('/')}/commands/{payload.name}",
                json=body,
                headers=_bots_headers(),
            )
    except httpx.HTTPError as exc:
        logger.warning("Bots service unreachable for /%s", payload.name, exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="The bot service is not responding",
        ) from exc

    if response.is_success:
        return {"ok": True}

    # A 4xx from the bot is a message for the person who typed the command
    # ("you're not in a voice channel"), so it is passed through as-is. Anything
    # else is the bot's problem, not theirs.
    if response.is_client_error:
        try:
            detail = response.json().get("detail", "The bot rejected that command")
        except ValueError:
            detail = "The bot rejected that command"
        raise HTTPException(status_code=response.status_code, detail=detail)

    logger.warning("Bots service failed /%s with %s", payload.name, response.status_code)
    raise HTTPException(
        status_code=status.HTTP_502_BAD_GATEWAY, detail="The bot could not run that command"
    )
