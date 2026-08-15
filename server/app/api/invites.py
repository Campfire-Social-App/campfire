import uuid
from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select

from app.core.deps import AdminUser, DbSession
from app.models.invite import Invite
from app.schemas.invite import InviteCreateRequest, InviteRead

router = APIRouter(prefix="/api/invites", tags=["invites"])


@router.post("", response_model=InviteRead, status_code=status.HTTP_201_CREATED)
async def create_invite(payload: InviteCreateRequest, admin: AdminUser, db: DbSession) -> InviteRead:
    expires_at = None
    if payload.expires_in_hours is not None:
        expires_at = datetime.now(UTC) + timedelta(hours=payload.expires_in_hours)

    invite = Invite(created_by_id=admin.id, max_uses=payload.max_uses, expires_at=expires_at)
    db.add(invite)
    await db.commit()
    await db.refresh(invite)
    return invite


@router.get("", response_model=list[InviteRead])
async def list_invites(admin: AdminUser, db: DbSession) -> list[InviteRead]:
    result = await db.execute(select(Invite).order_by(Invite.created_at.desc()))
    return list(result.scalars().all())


@router.delete("/{invite_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_invite(invite_id: uuid.UUID, admin: AdminUser, db: DbSession) -> None:
    invite = await db.get(Invite, invite_id)
    if invite is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Convite não encontrado")
    await db.delete(invite)
    await db.commit()
