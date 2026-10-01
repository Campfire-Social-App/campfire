import uuid
from datetime import datetime

from pydantic import BaseModel


class AudioEventIn(BaseModel):
    platform: str
    event_type: str
    channel_id: uuid.UUID | None = None
    session_id: uuid.UUID | None = None
    detail: dict = {}
    client_ts: datetime | None = None


class AudioEventBatchIn(BaseModel):
    events: list[AudioEventIn]
