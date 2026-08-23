import uuid

from pydantic import BaseModel


class VoiceTokenResponse(BaseModel):
    token: str
    url: str
    room: str


class MoveVoiceParticipantRequest(BaseModel):
    channel_id: uuid.UUID
