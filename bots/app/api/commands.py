import logging

from fastapi import APIRouter, Depends, Header, HTTPException, Request, status
from pydantic import BaseModel, Field

from app.core.config import get_settings
from app.core.registry import CommandContext, CommandError, CommandSpec, Registry

router = APIRouter(tags=["commands"])
logger = logging.getLogger(__name__)


async def require_core_server(
    x_campfire_bot_secret: str = Header(default=""),
) -> None:
    """Only the core server may drive the bots.

    This service is never published by Caddy, so this is a second line rather
    than the only one — but a shared secret is cheap and means a stray container
    on the same network can't make the bot join calls.
    """
    expected = get_settings().bots_shared_secret
    if not expected or x_campfire_bot_secret != expected:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authorised")


class CommandUser(BaseModel):
    id: str
    username: str


class RunCommandRequest(BaseModel):
    """The core server's account of who ran what, and where.

    `voice_channel_id` comes from the server's own voice state, never from the
    client — a command can only ever act on the call its caller is really in.
    """

    user: CommandUser
    text_channel_id: str
    voice_channel_id: str | None = None
    args: str = Field(default="", max_length=2000)


def _registry(request: Request) -> Registry:
    return request.app.state.registry


@router.get(
    "/commands",
    response_model=list[CommandSpec],
    dependencies=[Depends(require_core_server)],
)
async def list_commands(registry: Registry = Depends(_registry)) -> list[CommandSpec]:
    return registry.specs()


@router.post(
    "/commands/{name}",
    status_code=status.HTTP_202_ACCEPTED,
    dependencies=[Depends(require_core_server)],
)
async def run_command(
    name: str, payload: RunCommandRequest, registry: Registry = Depends(_registry)
) -> dict[str, bool]:
    bot = registry.bot_for(name)
    if bot is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"/{name} não existe")

    context = CommandContext(
        user_id=payload.user.id,
        username=payload.user.username,
        text_channel_id=payload.text_channel_id,
        voice_channel_id=payload.voice_channel_id,
        args=payload.args,
    )
    try:
        await bot.run(name, context)
    except CommandError as exc:
        # A refusal the caller should see, passed back for the core server to
        # relay as a toast rather than posted in the channel.
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc
    except Exception as exc:
        logger.exception("/%s failed for %s", name, payload.user.username)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="O bot falhou ao executar o comando",
        ) from exc

    return {"ok": True}
