from pydantic import BaseModel


class VoiceTokenResponse(BaseModel):
    token: str
    url: str
    room: str
