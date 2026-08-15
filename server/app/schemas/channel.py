import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, field_validator

from app.models.channel import ChannelType


class ChannelCreateRequest(BaseModel):
    name: str
    type: ChannelType
    position: int = 0

    @field_validator("type")
    @classmethod
    def _reject_dm(cls, value: ChannelType) -> ChannelType:
        # DM channels are created implicitly by /api/dms, never by an admin here.
        if value is ChannelType.DM:
            raise ValueError("Channels of type 'dm' cannot be created directly")
        return value


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
