from enum import StrEnum
from typing import Any

from pydantic import BaseModel


class GatewayEventType(StrEnum):
    READY = "READY"
    MESSAGE_CREATE = "MESSAGE_CREATE"
    MESSAGE_UPDATE = "MESSAGE_UPDATE"
    MESSAGE_DELETE = "MESSAGE_DELETE"
    MESSAGE_REACTION_UPDATE = "MESSAGE_REACTION_UPDATE"
    USER_UPDATE = "USER_UPDATE"
    TYPING_START = "TYPING_START"
    PRESENCE_UPDATE = "PRESENCE_UPDATE"
    VOICE_STATE_UPDATE = "VOICE_STATE_UPDATE"
    CHANNEL_CREATE = "CHANNEL_CREATE"
    CHANNEL_UPDATE = "CHANNEL_UPDATE"
    CHANNEL_DELETE = "CHANNEL_DELETE"
    # Upsert of one DM conversation, sent only to its participants — carries the
    # per-viewer unread count, so it's built separately for each recipient.
    DM_UPDATE = "DM_UPDATE"
    # Call signalling inside a DM (ring / accept / decline / cancel). Only the two
    # members ever see it; the media itself rides on LiveKit, keyed by channel id.
    DM_CALL = "DM_CALL"


class GatewayEvent(BaseModel):
    op: GatewayEventType
    data: dict[str, Any]
