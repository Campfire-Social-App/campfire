import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict

from app.schemas.attachment import AttachmentRead


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    username: str
    is_admin: bool
    is_banned: bool = False
    timed_out_until: datetime | None = None
    avatar_url: str | None = None
    created_at: datetime


class UserAvatarUpdateRequest(BaseModel):
    attachment_id: uuid.UUID


class ModerationMessageRead(BaseModel):
    id: uuid.UUID
    channel_id: uuid.UUID
    channel_name: str
    content: str
    created_at: datetime
    edited_at: datetime | None
    attachments: list[AttachmentRead]


class UserModerationOverview(BaseModel):
    user: UserRead
    messages: list[ModerationMessageRead]
