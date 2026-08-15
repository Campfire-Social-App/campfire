import enum
import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, Integer, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class ChannelType(str, enum.Enum):
    TEXT = "text"
    VOICE = "voice"
    # A direct-message conversation is a channel too: it holds messages, so it
    # reuses the whole message/attachment/reply/typing machinery. What sets it
    # apart is visibility — it never shows up in the channel list, and only its
    # members (see DMParticipant) can read or post in it.
    DM = "dm"


class Channel(Base):
    __tablename__ = "channels"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    type: Mapped[ChannelType] = mapped_column(
        Enum(ChannelType, name="channel_type", native_enum=True), nullable=False
    )
    position: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    # DM channels only: order-independent identity of the pair ("<uuid>:<uuid>",
    # sorted). UNIQUE, so "A opens a DM with B" and "B opens a DM with A" racing
    # each other can't produce two conversations for the same pair.
    dm_key: Mapped[str | None] = mapped_column(
        String(73), nullable=True, unique=True, index=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
