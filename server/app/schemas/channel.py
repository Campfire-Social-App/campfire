import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict

from app.models.channel import ChannelType


class ChannelCreateRequest(BaseModel):
    name: str
    type: ChannelType
    position: int = 0


class ChannelUpdateRequest(BaseModel):
    name: str | None = None
    position: int | None = None


class ChannelRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    type: ChannelType
    position: int
    created_at: datetime
