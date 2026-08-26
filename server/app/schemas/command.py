import uuid

from pydantic import BaseModel, Field


class SlashCommand(BaseModel):
    """One command as advertised by the bots service, for the composer's `/` popup."""

    name: str
    description: str
    # Argument hint shown next to the name, e.g. "<url ou busca>". Empty when
    # the command takes none.
    usage: str = ""
    # Whether invoking it requires the caller to be in a voice channel. The
    # bots service enforces it; this is only so the client can say why upfront.
    requires_voice: bool = False


class RunCommandRequest(BaseModel):
    """What the composer sends when a message turns out to be a slash command."""

    channel_id: uuid.UUID
    name: str = Field(min_length=1, max_length=32, pattern=r"^[a-z0-9_-]+$")
    args: str = Field(default="", max_length=2000)
