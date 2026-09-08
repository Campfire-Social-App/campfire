import uuid
from datetime import datetime

from sqlalchemy import JSON, Boolean, DateTime, ForeignKey, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    username: Mapped[str] = mapped_column(String(32), unique=True, index=True, nullable=False)
    display_name: Mapped[str | None] = mapped_column(String(64), nullable=True)
    # Denormalized profile summary used by member/message identity rows without
    # issuing one profile query per user.
    identity_plate_decoration: Mapped[str] = mapped_column(
        String(32), default="none", nullable=False
    )
    custom_identity_plate_data: Mapped[dict | None] = mapped_column(
        "custom_identity_plate", JSON, nullable=True
    )
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    is_admin: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    # A bot is a normal account driven by the bots service rather than by a
    # person: it logs in, holds a gateway connection (which is what makes it
    # show as online) and posts messages like anyone else. The flag exists so
    # the clients can render the BOT badge and skip the moderation/DM affordances.
    is_bot: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_banned: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    timed_out_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    avatar_attachment_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey(
            "attachments.id", ondelete="SET NULL", use_alter=True,
            name="fk_users_avatar_attachment_id_attachments",
        ),
        nullable=True,
    )
    banner_attachment_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey(
            "attachments.id", ondelete="SET NULL", use_alter=True,
            name="fk_users_banner_attachment_id_attachments",
        ),
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    @property
    def avatar_url(self) -> str | None:
        return f"/api/uploads/{self.avatar_attachment_id}" if self.avatar_attachment_id else None

    @property
    def banner_url(self) -> str | None:
        return f"/api/uploads/{self.banner_attachment_id}" if self.banner_attachment_id else None

    @property
    def custom_identity_plate(self) -> dict | None:
        asset = self.custom_identity_plate_data
        if not asset:
            return None
        return {
            "src": f"/api/uploads/{asset['attachment_id']}",
            "poster_src": (
                f"/api/uploads/{asset['poster_attachment_id']}"
                if asset.get("poster_attachment_id")
                else None
            ),
            "format": asset["format"],
            "source_size": asset["source_size"],
            "animated": asset["animated"],
        }
