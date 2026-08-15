import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.attachment import AttachmentRead
from app.schemas.user import UserRead


class MessageCreateRequest(BaseModel):
    content: str = Field(min_length=1, max_length=4000)
    attachment_ids: list[uuid.UUID] = Field(default_factory=list)


class MessageUpdateRequest(BaseModel):
    content: str = Field(min_length=1, max_length=4000)


class MessageRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    channel_id: uuid.UUID
    author: UserRead
    content: str
    created_at: datetime
    edited_at: datetime | None
    attachments: list[AttachmentRead] = Field(default_factory=list)


class MessagePage(BaseModel):
    messages: list[MessageRead]
    has_more: bool
