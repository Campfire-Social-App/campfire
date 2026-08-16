import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict

from app.models.attachment import Attachment


class AttachmentRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    filename: str
    content_type: str
    size_bytes: int
    url: str
    created_at: datetime

    @classmethod
    def from_model(cls, attachment: Attachment) -> "AttachmentRead":
        """Builds the client-facing view. `url` points at the download route
        rather than the file on disk: the stored name is a random uuid, so only
        that route knows the real filename and what may be shown inline."""
        return cls(
            id=attachment.id,
            filename=attachment.filename,
            content_type=attachment.content_type,
            size_bytes=attachment.size_bytes,
            url=f"/api/uploads/{attachment.id}",
            created_at=attachment.created_at,
        )
