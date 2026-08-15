import uuid
from datetime import datetime

from pydantic import BaseModel

from app.schemas.user import UserRead


class DMOpenRequest(BaseModel):
    user_id: uuid.UUID


class DMConversationRead(BaseModel):
    """A 1:1 conversation as seen by one specific member — `recipient` and
    `unread_count` are both relative to whoever asked."""

    id: uuid.UUID
    recipient: UserRead
    last_message_at: datetime | None
    unread_count: int
