import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.attachment import AttachmentRead

ProfileDecoration = Literal["none", "spectral_warden", "ember_sovereign", "neon_revenant", "custom"]
DecorationRole = Literal["card-frame", "card-top", "avatar-frame", "identity-plate"]


class DecorationAssetRead(BaseModel):
    src: str
    poster_src: str | None = None
    format: Literal["png", "gif"]
    source_size: tuple[int, int]
    animated: bool


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    username: str
    display_name: str | None = None
    identity_plate_decoration: ProfileDecoration = "none"
    custom_identity_plate: DecorationAssetRead | None = None
    is_admin: bool
    is_bot: bool = False
    is_banned: bool = False
    timed_out_until: datetime | None = None
    avatar_url: str | None = None
    banner_url: str | None = None
    created_at: datetime


class UserAvatarUpdateRequest(BaseModel):
    attachment_id: uuid.UUID | None


class UserBannerUpdateRequest(BaseModel):
    attachment_id: uuid.UUID | None


ProfileLayout = Literal["standard", "minimal", "gamer", "creator", "developer"]
BannerType = Literal["solid", "gradient", "image"]
BackgroundType = Literal["solid", "gradient", "glass"]
AvatarDecoration = Literal[
    "none", "admin", "founder", "developer", "bug_hunter", "early_adopter", "event_winner"
]
ProfileEffect = Literal["none", "ember", "glow"]


class UserProfileUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    display_name: str | None = Field(default=None, max_length=64)
    bio: str | None = Field(default=None, max_length=500)
    custom_status: str | None = Field(default=None, max_length=128)
    profile_layout: ProfileLayout = "standard"
    accent_color: str = "#FF6A00"
    banner_type: BannerType = "gradient"
    banner_color: str = "#FF6A00"
    banner_secondary_color: str = "#9A3412"
    background_type: BackgroundType = "solid"
    avatar_decoration: AvatarDecoration = "none"
    profile_decoration: ProfileDecoration = "none"
    avatar_frame_decoration: ProfileDecoration = "none"
    identity_plate_decoration: ProfileDecoration = "none"
    profile_effect: ProfileEffect = "none"

    @field_validator("display_name", "bio", "custom_status")
    @classmethod
    def empty_to_none(cls, value: str | None) -> str | None:
        value = value.strip() if value else None
        return value or None

    @field_validator("accent_color", "banner_color", "banner_secondary_color")
    @classmethod
    def valid_hex_color(cls, value: str) -> str:
        import re

        if re.fullmatch(r"#[0-9A-Fa-f]{6}", value) is None:
            raise ValueError("must be a six-digit hex color")
        return value.upper()


class UserProfileRead(UserProfileUpdate):
    user: UserRead
    custom_decoration_assets: dict[DecorationRole, DecorationAssetRead] = Field(default_factory=dict)
    badges: list[str]
    activities: list[dict[str, str | None]] = Field(default_factory=list)


class ModerationMessageRead(BaseModel):
    id: uuid.UUID
    channel_id: uuid.UUID
    channel_name: str
    content: str
    created_at: datetime
    edited_at: datetime | None
    attachments: list[AttachmentRead]


class UserModerationOverview(BaseModel):
    user: UserRead
    messages: list[ModerationMessageRead]
