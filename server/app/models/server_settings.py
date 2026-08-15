import uuid
from datetime import datetime

from sqlalchemy import DateTime, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base

SINGLETON_ID = uuid.UUID("00000000-0000-0000-0000-000000000001")


class ServerSettings(Base):
    """Singleton row representing the single self-hosted 'guild'."""

    __tablename__ = "server_settings"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=lambda: SINGLETON_ID)
    name: Mapped[str] = mapped_column(String(100), default="Campfire", nullable=False)
    icon_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
