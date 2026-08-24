import logging
import uuid
from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select

from app.core.deps import AdminUser, CurrentUser, DbSession
from app.gateway.events import GatewayEvent, GatewayEventType
from app.gateway.manager import manager
from app.models.attachment import Attachment
from app.models.channel import Channel, ChannelType
from app.models.message import Message
from app.models.user import User
from app.schemas.attachment import AttachmentRead
from app.schemas.user import (
    ModerationMessageRead,
    UserAvatarUpdateRequest,
    UserBannerUpdateRequest,
    UserModerationOverview,
    UserRead,
)
from app.services.livekit_service import disconnect_participant

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


@router.get("", response_model=list[UserRead])
async def list_users(user: CurrentUser, db: DbSession) -> list[User]:
    """All registered members. Single-server MVP: no per-channel privacy boundary,
    so any authenticated member can see the full member list (matches PLANO.md scope)."""
    result = await db.execute(select(User).order_by(User.username))
    return list(result.scalars().all())


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
    attachment = await _profile_image(payload.attachment_id, user, db)
    user.avatar_attachment_id = attachment.id
    await db.commit()
    await db.refresh(user)
    return await _broadcast_user(user)


@router.put("/@me/banner", response_model=UserRead)
async def update_banner(
    payload: UserBannerUpdateRequest, user: CurrentUser, db: DbSession
) -> UserRead:
    banner = await _profile_image(payload.attachment_id, user, db)
    user.banner_attachment_id = banner.id
    await db.commit()
    await db.refresh(user)
    return await _broadcast_user(user)
