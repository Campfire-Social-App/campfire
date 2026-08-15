import uuid

from fastapi import APIRouter, HTTPException, status

from app.core.deps import CurrentUser, DbSession
from app.models.user import User
from app.schemas.dm import DMConversationRead, DMOpenRequest
from app.services import dm_service

router = APIRouter(prefix="/api/dms", tags=["dms"])


@router.get("", response_model=list[DMConversationRead])
async def list_dms(user: CurrentUser, db: DbSession) -> list[DMConversationRead]:
    return await dm_service.list_conversations(db, user.id)


@router.post("", response_model=DMConversationRead, status_code=status.HTTP_200_OK)
async def open_dm(payload: DMOpenRequest, user: CurrentUser, db: DbSession) -> DMConversationRead:
    """Get-or-create the conversation with another member.

    Deliberately idempotent (and 200, not 201): the client calls this every time
    someone clicks a member, and reopening an existing conversation must land in
    the same place rather than starting a second one.
    """
    if payload.user_id == user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot open a DM with yourself"
        )
    recipient = await db.get(User, payload.user_id)
    if recipient is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    channel = await dm_service.get_or_create_dm(db, user.id, recipient.id)
    conversation = await dm_service.to_conversation_read(db, channel, user.id)
    if conversation is None:  # pragma: no cover — both participants were just verified
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Conversation not available"
        )
    return conversation


@router.post("/{channel_id}/read", status_code=status.HTTP_204_NO_CONTENT)
async def mark_dm_read(channel_id: uuid.UUID, user: CurrentUser, db: DbSession) -> None:
    if not await dm_service.is_participant(db, channel_id, user.id):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Conversation not found")
    await dm_service.mark_read(db, channel_id, user.id)
