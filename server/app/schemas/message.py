import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.schemas.attachment import AttachmentRead
from app.schemas.user import UserRead


class MessageCreateRequest(BaseModel):
    """A photo can be the whole message, so `content` is optional — what must not
    happen is a message that is empty of both."""

    content: str = Field(default="", max_length=4000)
    attachment_ids: list[uuid.UUID] = Field(default_factory=list)
    reply_to_id: uuid.UUID | None = None

    @model_validator(mode="after")
    def _reject_empty(self) -> "MessageCreateRequest":
        if not self.content.strip() and not self.attachment_ids:
            raise ValueError("A message needs text or at least one attachment")
        return self


class MessageUpdateRequest(BaseModel):
    content: str = Field(min_length=1, max_length=4000)


class MessageReplyPreview(BaseModel):
    """Trimmed snapshot of the message being replied to — just enough to
    render the quoted preview line, without nesting a full MessageRead
    (which would recurse if that message were itself a reply)."""

    id: uuid.UUID
    author: UserRead
    content: str
    has_attachments: bool


class MessageReactionRead(BaseModel):
    type: str
    count: int
    reacted_by_me: bool


class MessageReactionUpdate(BaseModel):
    message_id: uuid.UUID
    channel_id: uuid.UUID
    type: str
    count: int
    user_id: uuid.UUID
    reacted: bool


class MessageRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    channel_id: uuid.UUID
    author: UserRead
    content: str
    created_at: datetime
    edited_at: datetime | None
    attachments: list[AttachmentRead] = Field(default_factory=list)
    reply_to: MessageReplyPreview | None = None
    reactions: list[MessageReactionRead] = Field(default_factory=list)


class MessagePage(BaseModel):
    messages: list[MessageRead]
    has_more: bool
