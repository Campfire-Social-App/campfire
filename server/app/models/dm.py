import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class DMParticipant(Base):
    """Membership row for a DM channel — the read/write ACL for that conversation.

    Modelled as a table rather than two columns on the channel so group DMs stay
    possible later without a migration; today the API only ever creates pairs.
    """

    __tablename__ = "dm_participants"

    channel_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("channels.id", ondelete="CASCADE"), primary_key=True
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
        index=True,
    )
    # NULL means "never opened" — every message in the conversation counts as unread.
    last_read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
