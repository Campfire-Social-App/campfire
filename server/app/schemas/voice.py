import uuid

from pydantic import BaseModel


class VoiceTokenResponse(BaseModel):
    token: str
    url: str
    room: str


class VoiceTokenRequest(BaseModel):
    muted: bool = False
    deafened: bool = False


class MoveVoiceParticipantRequest(BaseModel):
    channel_id: uuid.UUID


class UpdateOwnVoiceStateRequest(BaseModel):
    muted: bool
    deafened: bool
    screen_sharing: bool | None = None
