import uuid
from datetime import datetime

from sqlalchemy import BigInteger, DateTime, ForeignKey, Identity, String, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class AudioEvent(Base):
    """Append-only diagnostic trail for microphone/audio-device bugs in
    production. Written from two independent sources: clients report what
    happened on-device (`source="client"`), and the LiveKit webhook reports
    what the SFU actually observed (`source="server"`) — the two don't depend
    on each other being bug-free, which is the point."""

    __tablename__ = "audio_events"

    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    # SET NULL rather than CASCADE: a diagnostic record should outlive the
    # user/channel it was about.
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    channel_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("channels.id", ondelete="SET NULL"), nullable=True, index=True
    )
    # Set by the client to one UUID per call attempt, so every event from that
    # attempt can be pulled with a single WHERE. Server-origin events (the
    # webhook has no way to know it) leave this null.
    session_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True, index=True)
    source: Mapped[str] = mapped_column(String(16), nullable=False)
    platform: Mapped[str | None] = mapped_column(String(16), nullable=True)
    event_type: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    detail: Mapped[dict] = mapped_column(JSONB, nullable=False, server_default="{}")
    client_ts: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False, index=True
    )
