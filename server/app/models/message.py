import uuid
from datetime import datetime

from sqlalchemy import BigInteger, DateTime, ForeignKey, Identity, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class Message(Base):
    __tablename__ = "messages"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    # Monotonic, DB-assigned ordering key: `created_at` alone can tie under fast writes
    # (Postgres timestamp resolution), which breaks stable pagination ordering.
    seq: Mapped[int] = mapped_column(BigInteger, Identity(), nullable=False, unique=True, index=True)
    channel_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("channels.id", ondelete="CASCADE"), nullable=False, index=True
    )
    author_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    content: Mapped[str] = mapped_column(Text, nullable=False)
    # SET NULL rather than CASCADE: deleting the original shouldn't delete
    # every reply to it, just sever the link (the reply falls back to
    # rendering as a normal message).
    reply_to_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("messages.id", ondelete="SET NULL"), nullable=True, index=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False, index=True
    )
    edited_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
