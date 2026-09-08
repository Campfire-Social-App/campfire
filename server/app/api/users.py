import logging
import uuid
from datetime import UTC, datetime, timedelta
from pathlib import Path

import aiofiles
from fastapi import APIRouter, HTTPException, UploadFile, status
from sqlalchemy import select

from app.core.config import get_settings
from app.core.deps import AdminUser, CurrentUser, DbSession
from app.gateway.events import GatewayEvent, GatewayEventType
from app.gateway.manager import manager
from app.models.attachment import Attachment
from app.models.channel import Channel, ChannelType
from app.models.message import Message
from app.models.user import User
from app.models.user_profile import UserProfile
from app.schemas.attachment import AttachmentRead
from app.schemas.user import (
    DecorationAssetRead,
    ModerationMessageRead,
    UserAvatarUpdateRequest,
    UserBannerUpdateRequest,
    UserModerationOverview,
    UserProfileRead,
    UserProfileUpdate,
    UserRead,
)
from app.services.livekit_service import disconnect_participant
from app.services.profile_decoration_assets import (
    ROLE_SPECS,
    DecorationValidationError,
    validate_decoration,
)

router = APIRouter(prefix="/api/users", tags=["users"])
logger = logging.getLogger(__name__)

PROFILE_IMAGE_TYPES = {"image/png", "image/jpeg", "image/gif", "image/webp", "image/avif"}
MAX_PROFILE_IMAGE_BYTES = 8 * 1024 * 1024


async def _moderation_target(user_id: uuid.UUID, admin: AdminUser, db: DbSession) -> User:
    target = await db.get(User, user_id)
    if target is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    if target.id == admin.id or target.is_admin:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Administrators cannot apply this action to an administrator",
        )
    return target


async def _disconnect_from_voice(user_id: uuid.UUID) -> bool:
    voice_state = manager.voice_state.get(user_id)
    if voice_state is None:
        return False
    await disconnect_participant(identity=str(user_id), room=str(voice_state.channel_id))
    return True


async def _profile_image(attachment_id: uuid.UUID, user: User, db: DbSession) -> Attachment:
    attachment = await db.get(Attachment, attachment_id)
    if attachment is None or attachment.uploaded_by_id != user.id or attachment.message_id is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Image not found")
    if attachment.content_type not in PROFILE_IMAGE_TYPES:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail="Use a supported image",
        )
    if attachment.size_bytes > MAX_PROFILE_IMAGE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_CONTENT_TOO_LARGE,
            detail="Profile image exceeds 8 MB",
        )
    return attachment


async def _broadcast_user(user: User) -> UserRead:
    result = UserRead.model_validate(user)
    await manager.broadcast(
        GatewayEvent(op=GatewayEventType.USER_UPDATE, data=result.model_dump(mode="json"))
    )
    return result


def _profile_read(user: User, profile: UserProfile | None) -> UserProfileRead:
    values = UserProfileUpdate().model_dump() if profile is None else {
        key: getattr(profile, key) for key in UserProfileUpdate.model_fields
    }
    badges = (["bot"] if user.is_bot else []) + (["admin"] if user.is_admin else [])
    assets = (profile.custom_decoration_assets_data or {}) if profile is not None else {}
    return UserProfileRead(
        user=UserRead.model_validate(user),
        badges=badges,
        custom_decoration_assets={
            role: _decoration_asset_read(asset) for role, asset in assets.items()
        },
        **values,
    )


def _decoration_asset_read(asset: dict) -> DecorationAssetRead:
    return DecorationAssetRead(
        src=f"/api/uploads/{asset['attachment_id']}",
        poster_src=(
            f"/api/uploads/{asset['poster_attachment_id']}"
            if asset.get("poster_attachment_id")
            else None
        ),
        format=asset["format"],
        source_size=tuple(asset["source_size"]),
        animated=asset["animated"],
    )


async def _write_upload(path: Path, data: bytes) -> None:
    async with aiofiles.open(path, "wb") as output:
        await output.write(data)


@router.get("", response_model=list[UserRead])
async def list_users(user: CurrentUser, db: DbSession) -> list[User]:
    """All registered members. Single-server MVP: no per-channel privacy boundary,
    so any authenticated member can see the full member list (matches PLANO.md scope)."""
    result = await db.execute(select(User).order_by(User.username))
    return list(result.scalars().all())


@router.get("/{user_id}/profile", response_model=UserProfileRead)
async def get_user_profile(user_id: uuid.UUID, _user: CurrentUser, db: DbSession) -> UserProfileRead:
    target = await db.get(User, user_id)
    if target is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return _profile_read(target, await db.get(UserProfile, user_id))


@router.patch("/@me/profile", response_model=UserProfileRead)
async def update_my_profile(
    payload: UserProfileUpdate, user: CurrentUser, db: DbSession
) -> UserProfileRead:
    profile = await db.get(UserProfile, user.id)
    if profile is None:
        profile = UserProfile(user_id=user.id)
        db.add(profile)
    custom_assets = profile.custom_decoration_assets_data or {}
    if payload.profile_decoration == "custom" and not (
        custom_assets.get("card-frame") or custom_assets.get("card-top")
    ):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="Upload a custom card frame or card top before selecting Custom",
        )
    if payload.avatar_frame_decoration == "custom" and not custom_assets.get("avatar-frame"):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="Upload a custom avatar frame before selecting Custom",
        )
    if payload.identity_plate_decoration == "custom" and not custom_assets.get("identity-plate"):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="Upload a custom identity plate before selecting Custom",
        )
    for key, value in payload.model_dump().items():
        setattr(profile, key, value)
    user.display_name = payload.display_name
    user.identity_plate_decoration = payload.identity_plate_decoration
    user.custom_identity_plate_data = custom_assets.get("identity-plate")
    await db.commit()
    await db.refresh(profile)
    await db.refresh(user)
    result = _profile_read(user, profile)
    await manager.broadcast(
        GatewayEvent(
            op=GatewayEventType.USER_UPDATE,
            data=UserRead.model_validate(user).model_dump(mode="json"),
        )
    )
    return result


@router.post("/@me/decorations/{role}", response_model=UserProfileRead)
async def upload_my_decoration(
    role: str, file: UploadFile, user: CurrentUser, db: DbSession
) -> UserProfileRead:
    if role not in ROLE_SPECS:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Unknown decoration role")
    spec = ROLE_SPECS[role]
    data = await file.read(spec["bytes"] + 1)
    if len(data) > spec["bytes"]:
        raise HTTPException(
            status_code=status.HTTP_413_CONTENT_TOO_LARGE,
            detail=f"{role} exceeds the {spec['bytes'] // (1024 * 1024)} MiB limit",
        )
    try:
        validated = validate_decoration(data, role)
    except DecorationValidationError as error:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail=str(error)
        ) from error

    upload_dir = Path(get_settings().upload_dir)
    upload_dir.mkdir(parents=True, exist_ok=True)
    attachment = Attachment(
        id=uuid.uuid4(),
        uploaded_by_id=user.id,
        filename=f"custom-{role}{validated.extension}",
        content_type=validated.content_type,
        size_bytes=len(data),
        storage_path="",
    )
    attachment.storage_path = f"{attachment.id.hex}{validated.extension}"
    poster: Attachment | None = None
    if validated.poster is not None:
        poster = Attachment(
            id=uuid.uuid4(),
            uploaded_by_id=user.id,
            filename=f"custom-{role}-poster.png",
            content_type="image/png",
            size_bytes=len(validated.poster),
            storage_path="",
        )
        poster.storage_path = f"{poster.id.hex}.png"

    written_paths = [upload_dir / attachment.storage_path]
    replaced_paths: list[Path] = []
    await _write_upload(written_paths[0], data)
    if poster is not None and validated.poster is not None:
        written_paths.append(upload_dir / poster.storage_path)
        await _write_upload(written_paths[-1], validated.poster)

    try:
        db.add(attachment)
        if poster is not None:
            db.add(poster)
        profile = await db.get(UserProfile, user.id)
        if profile is None:
            profile = UserProfile(user_id=user.id)
            db.add(profile)
        assets = dict(profile.custom_decoration_assets_data or {})
        replaced = assets.get(role)
        if replaced:
            for key in ("attachment_id", "poster_attachment_id"):
                replaced_id = replaced.get(key)
                if not replaced_id:
                    continue
                previous = await db.get(Attachment, uuid.UUID(replaced_id))
                if previous is not None and previous.uploaded_by_id == user.id:
                    replaced_paths.append(upload_dir / previous.storage_path)
                    await db.delete(previous)
        asset = {
            "attachment_id": str(attachment.id),
            "poster_attachment_id": str(poster.id) if poster else None,
            "format": validated.extension.removeprefix("."),
            "source_size": list(validated.source_size),
            "animated": validated.animated,
        }
        assets[role] = asset
        profile.custom_decoration_assets_data = assets
        if role == "identity-plate":
            user.custom_identity_plate_data = asset
        await db.commit()
        await db.refresh(profile)
        await db.refresh(user)
    except Exception:
        for path in written_paths:
            path.unlink(missing_ok=True)
        raise
    for path in replaced_paths:
        path.unlink(missing_ok=True)

    result = _profile_read(user, profile)
    await manager.broadcast(
        GatewayEvent(
            op=GatewayEventType.USER_UPDATE,
            data=UserRead.model_validate(user).model_dump(mode="json"),
        )
    )
    return result


@router.delete("/@me/decorations/{role}", response_model=UserProfileRead)
async def delete_my_decoration(
    role: str, user: CurrentUser, db: DbSession
) -> UserProfileRead:
    if role not in ROLE_SPECS:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Unknown decoration role")
    profile = await db.get(UserProfile, user.id)
    if profile is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Decoration not found")
    assets = dict(profile.custom_decoration_assets_data or {})
    removed = assets.pop(role, None)
    if removed is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Decoration not found")
    profile.custom_decoration_assets_data = assets
    if role in {"card-frame", "card-top"} and not (
        assets.get("card-frame") or assets.get("card-top")
    ):
        profile.profile_decoration = "none"
    elif role == "avatar-frame" and profile.avatar_frame_decoration == "custom":
        profile.avatar_frame_decoration = "none"
    elif role == "identity-plate":
        if profile.identity_plate_decoration == "custom":
            profile.identity_plate_decoration = "none"
        user.identity_plate_decoration = profile.identity_plate_decoration
        user.custom_identity_plate_data = None

    upload_dir = Path(get_settings().upload_dir)
    paths: list[Path] = []
    for key in ("attachment_id", "poster_attachment_id"):
        attachment_id = removed.get(key)
        if not attachment_id:
            continue
        attachment = await db.get(Attachment, uuid.UUID(attachment_id))
        if attachment is not None and attachment.uploaded_by_id == user.id:
            paths.append(upload_dir / attachment.storage_path)
            await db.delete(attachment)
    await db.commit()
    await db.refresh(profile)
    await db.refresh(user)
    for path in paths:
        path.unlink(missing_ok=True)
    result = _profile_read(user, profile)
    await manager.broadcast(
        GatewayEvent(
            op=GatewayEventType.USER_UPDATE,
            data=UserRead.model_validate(user).model_dump(mode="json"),
        )
    )
    return result


@router.get("/{user_id}/moderation", response_model=UserModerationOverview)
async def user_moderation_overview(
    user_id: uuid.UUID, _admin: AdminUser, db: DbSession
) -> UserModerationOverview:
    """Full public-server history for moderators. DMs are deliberately excluded."""
    target = await db.get(User, user_id)
    if target is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    rows = (
        await db.execute(
            select(Message, Channel.name)
            .join(Channel, Channel.id == Message.channel_id)
            .where(Message.author_id == user_id, Channel.type == ChannelType.TEXT)
            .order_by(Message.seq.desc())
        )
    ).all()
    message_ids = [message.id for message, _channel_name in rows]
    attachments_by_message: dict[uuid.UUID, list[AttachmentRead]] = {}
    if message_ids:
        attachments = (
            await db.execute(select(Attachment).where(Attachment.message_id.in_(message_ids)))
        ).scalars().all()
        for attachment in attachments:
            if attachment.message_id is not None:
                attachments_by_message.setdefault(attachment.message_id, []).append(
                    AttachmentRead.from_model(attachment)
                )

    return UserModerationOverview(
        user=UserRead.model_validate(target),
        messages=[
            ModerationMessageRead(
                id=message.id,
                channel_id=message.channel_id,
                channel_name=channel_name,
                content=message.content,
                created_at=message.created_at,
                edited_at=message.edited_at,
                attachments=attachments_by_message.get(message.id, []),
            )
            for message, channel_name in rows
        ],
    )


@router.post("/{user_id}/kick", status_code=status.HTTP_204_NO_CONTENT)
async def kick_user_from_voice(user_id: uuid.UUID, admin: AdminUser, db: DbSession) -> None:
    await _moderation_target(user_id, admin, db)
    if not await _disconnect_from_voice(user_id):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="User is not in voice")


@router.post("/{user_id}/ban", response_model=UserRead)
async def ban_user(user_id: uuid.UUID, admin: AdminUser, db: DbSession) -> UserRead:
    target = await _moderation_target(user_id, admin, db)
    target.is_banned = True
    target.timed_out_until = None
    await db.commit()
    await db.refresh(target)
    try:
        await _disconnect_from_voice(user_id)
    except Exception:
        logger.exception("Failed to disconnect banned user %s from voice", user_id)
    await manager.close_user_connections(user_id)
    result = UserRead.model_validate(target)
    await manager.broadcast(
        GatewayEvent(op=GatewayEventType.USER_UPDATE, data=result.model_dump(mode="json"))
    )
    return result


@router.post("/{user_id}/timeout", response_model=UserRead)
async def timeout_user(user_id: uuid.UUID, admin: AdminUser, db: DbSession) -> UserRead:
    target = await _moderation_target(user_id, admin, db)
    target.timed_out_until = datetime.now(UTC) + timedelta(hours=1)
    await db.commit()
    await db.refresh(target)
    try:
        await _disconnect_from_voice(user_id)
    except Exception:
        logger.exception("Failed to disconnect timed-out user %s from voice", user_id)
    result = UserRead.model_validate(target)
    await manager.broadcast(
        GatewayEvent(op=GatewayEventType.USER_UPDATE, data=result.model_dump(mode="json"))
    )
    return result


@router.put("/@me/avatar", response_model=UserRead)
async def update_avatar(payload: UserAvatarUpdateRequest, user: CurrentUser, db: DbSession) -> UserRead:
    attachment = (
        await _profile_image(payload.attachment_id, user, db)
        if payload.attachment_id is not None
        else None
    )
    user.avatar_attachment_id = attachment.id if attachment else None
    await db.commit()
    await db.refresh(user)
    return await _broadcast_user(user)


@router.put("/@me/banner", response_model=UserRead)
async def update_banner(
    payload: UserBannerUpdateRequest, user: CurrentUser, db: DbSession
) -> UserRead:
    banner = (
        await _profile_image(payload.attachment_id, user, db)
        if payload.attachment_id is not None
        else None
    )
    user.banner_attachment_id = banner.id if banner else None
    await db.commit()
    await db.refresh(user)
    return await _broadcast_user(user)
