from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select

from app.core.deps import CurrentUser, DbSession
from app.gateway.events import GatewayEvent, GatewayEventType
from app.gateway.manager import manager
from app.models.attachment import Attachment
from app.models.user import User
from app.schemas.user import UserAvatarUpdateRequest, UserRead

router = APIRouter(prefix="/api/users", tags=["users"])


@router.get("", response_model=list[UserRead])
async def list_users(user: CurrentUser, db: DbSession) -> list[User]:
    """All registered members. Single-server MVP: no per-channel privacy boundary,
    so any authenticated member can see the full member list (matches PLANO.md scope)."""
    result = await db.execute(select(User).order_by(User.username))
    return list(result.scalars().all())


@router.put("/@me/avatar", response_model=UserRead)
async def update_avatar(payload: UserAvatarUpdateRequest, user: CurrentUser, db: DbSession) -> UserRead:
    attachment = await db.get(Attachment, payload.attachment_id)
    if attachment is None or attachment.uploaded_by_id != user.id or attachment.message_id is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Image not found")
    if attachment.content_type not in {"image/png", "image/jpeg", "image/gif", "image/webp", "image/avif"}:
        raise HTTPException(status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE, detail="Use a supported image")
    if attachment.size_bytes > 5 * 1024 * 1024:
        raise HTTPException(status_code=status.HTTP_413_CONTENT_TOO_LARGE, detail="Profile image exceeds 5 MB")
    user.avatar_attachment_id = attachment.id
    await db.commit()
    await db.refresh(user)
    result = UserRead.model_validate(user)
    await manager.broadcast(GatewayEvent(op=GatewayEventType.USER_UPDATE, data=result.model_dump(mode="json")))
    return result
