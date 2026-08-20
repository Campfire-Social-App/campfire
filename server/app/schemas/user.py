import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    username: str
    is_admin: bool
    avatar_url: str | None = None
    created_at: datetime


class UserAvatarUpdateRequest(BaseModel):
    attachment_id: uuid.UUID
