import uuid
from datetime import datetime

from sqlalchemy import JSON, DateTime, ForeignKey, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class UserProfile(Base):
    __tablename__ = "user_profiles"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    display_name: Mapped[str | None] = mapped_column(String(64), nullable=True)
    bio: Mapped[str | None] = mapped_column(Text, nullable=True)
    custom_status: Mapped[str | None] = mapped_column(String(128), nullable=True)
    profile_layout: Mapped[str] = mapped_column(String(16), default="standard", nullable=False)
    accent_color: Mapped[str] = mapped_column(String(7), default="#FF6A00", nullable=False)
    banner_type: Mapped[str] = mapped_column(String(16), default="gradient", nullable=False)
    banner_color: Mapped[str] = mapped_column(String(7), default="#FF6A00", nullable=False)
    banner_secondary_color: Mapped[str] = mapped_column(
        String(7), default="#9A3412", nullable=False
    )
    background_type: Mapped[str] = mapped_column(String(16), default="solid", nullable=False)
    avatar_decoration: Mapped[str] = mapped_column(String(24), default="none", nullable=False)
    profile_decoration: Mapped[str] = mapped_column(String(32), default="none", nullable=False)
    avatar_frame_decoration: Mapped[str] = mapped_column(String(32), default="none", nullable=False)
    identity_plate_decoration: Mapped[str] = mapped_column(String(32), default="none", nullable=False)
    custom_decoration_assets_data: Mapped[dict] = mapped_column(
        "custom_decoration_assets", JSON, default=dict, nullable=False
    )
    profile_effect: Mapped[str] = mapped_column(String(24), default="none", nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )
