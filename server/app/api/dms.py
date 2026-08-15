import uuid

from fastapi import APIRouter, HTTPException, status

from app.core.deps import CurrentUser, DbSession
from app.gateway.manager import DMCallInvite, manager
from app.models.channel import Channel
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


async def _other_member_or_404(channel_id: uuid.UUID, user: CurrentUser, db: DbSession) -> User:
    """The person on the other end of `channel_id`. Non-participants get the same
    404 as a conversation that doesn't exist (see api/messages.py)."""
    other_id = await dm_service.other_participant_id(db, channel_id, user.id)
    if other_id is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Conversation not found")
    other = await db.get(User, other_id)
    if other is None:  # pragma: no cover — participant rows die with the account
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Conversation not found")
    return other


@router.post("/{channel_id}/call", status_code=status.HTTP_204_NO_CONTENT)
async def start_dm_call(channel_id: uuid.UUID, user: CurrentUser, db: DbSession) -> None:
    """Ring the other member. The media itself is a LiveKit room named after the
    channel — this only makes their client light up; the caller joins the room
    separately, via /api/voice/{channel_id}/token."""
    other = await _other_member_or_404(channel_id, user, db)

    existing = manager.pending_call(channel_id)
    if existing is not None and existing.caller_id != user.id:
        # Both sides hit call at once. Whoever rang first keeps the call; this
        # side is told to answer theirs instead of starting a second one.
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail=f"{other.username} is already calling you"
        )

    manager.set_pending_call(
        DMCallInvite(channel_id=channel_id, caller_id=user.id, callee_id=other.id)
    )

    # Before the ring itself: a call can be the first thing that ever happens in
    # a conversation, and the callee's rail needs somewhere to put it — answering
    # opens the DM, which has to exist on their side by then.
    channel = await db.get(Channel, channel_id)
    if channel is not None:
        await dm_service.push_conversation_update(db, channel)

    # Re-ringing an invite we already own is deliberate: it re-lights a client
    # that reconnected (and so lost the original frame) mid-ring.
    await manager.send_to_user(
        other.id, dm_service.call_event("ringing", channel_id, user.id, user.username)
    )


@router.post("/{channel_id}/call/accept", status_code=status.HTTP_204_NO_CONTENT)
async def accept_dm_call(channel_id: uuid.UUID, user: CurrentUser, db: DbSession) -> None:
    caller = await _other_member_or_404(channel_id, user, db)

    invite = manager.pending_call(channel_id)
    if invite is None or invite.callee_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="This call is no longer ringing"
        )

    manager.clear_pending_call(channel_id)
    await manager.send_to_user(
        caller.id, dm_service.call_event("accepted", channel_id, user.id, user.username)
    )


@router.delete("/{channel_id}/call", status_code=status.HTTP_204_NO_CONTENT)
async def end_dm_call(channel_id: uuid.UUID, user: CurrentUser, db: DbSession) -> None:
    """Hangs up a call that is still ringing — a cancel from the caller, a decline
    from the callee. Idempotent: with nothing ringing there is nothing to end
    (an answered call ends by leaving the LiveKit room, not through here)."""
    other = await _other_member_or_404(channel_id, user, db)

    invite = manager.pending_call(channel_id)
    if invite is None:
        return

    manager.clear_pending_call(channel_id)
    action = "cancelled" if invite.caller_id == user.id else "declined"
    await manager.send_to_user(
        other.id, dm_service.call_event(action, channel_id, user.id, user.username)
    )
