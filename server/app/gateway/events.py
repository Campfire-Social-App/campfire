from enum import StrEnum
from typing import Any

from pydantic import BaseModel


class GatewayEventType(StrEnum):
    READY = "READY"
    MESSAGE_CREATE = "MESSAGE_CREATE"
    MESSAGE_UPDATE = "MESSAGE_UPDATE"
    MESSAGE_DELETE = "MESSAGE_DELETE"
    TYPING_START = "TYPING_START"
    PRESENCE_UPDATE = "PRESENCE_UPDATE"
    VOICE_STATE_UPDATE = "VOICE_STATE_UPDATE"
    CHANNEL_CREATE = "CHANNEL_CREATE"
    CHANNEL_UPDATE = "CHANNEL_UPDATE"
    CHANNEL_DELETE = "CHANNEL_DELETE"


class GatewayEvent(BaseModel):
    op: GatewayEventType
    data: dict[str, Any]
