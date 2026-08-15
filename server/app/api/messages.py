import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy import select

from app.core.deps import CurrentUser, DbSession
from app.gateway.events import GatewayEvent, GatewayEventType
from app.gateway.manager import manager
from app.models.attachment import Attachment
from app.models.channel import Channel, ChannelType
from app.models.message import Message
from app.models.user import User
from app.schemas.attachment import AttachmentRead
from app.schemas.message import (
    MessageCreateRequest,
    MessagePage,
    MessageRead,
    MessageReplyPreview,
    MessageUpdateRequest,
)
from app.schemas.user import UserRead
from app.services import dm_service

router = APIRouter(tags=["messages"])


def _attachment_url(attachment: Attachment) -> str:
    return f"/uploads/{attachment.storage_path}"


async def _get_readable_channel_or_404(
    channel_id: uuid.UUID, user: CurrentUser, db: DbSession
) -> Channel:
    """Resolves a channel the user may read and post in: any text channel, or a
    DM they're a participant of. Non-participants get 404 rather than 403 — a DM
    they aren't in shouldn't be distinguishable from one that doesn't exist."""
    channel = await db.get(Channel, channel_id)
    if channel is None or channel.type == ChannelType.VOICE:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Text channel not found")
    if channel.type == ChannelType.DM and not await dm_service.is_participant(
        db, channel.id, user.id
    ):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Text channel not found")
    return channel


async def _dispatch(channel: Channel, event: GatewayEvent, db: DbSession) -> None:
    """Fans an event out to everyone who can see `channel` — the whole server for
    a text channel, only the two members for a DM."""
    if channel.type == ChannelType.DM:
        for user_id in await dm_service.participant_ids(db, channel.id):
            await manager.send_to_user(user_id, event)
    else:
        await manager.broadcast(event)


async def _push_dm_conversation(channel: Channel, db: DbSession) -> None:
    """Pushes the conversation to each participant's DM list. Sent alongside every
    DM message: it's how the recipient's rail learns about a conversation they've
    never opened, and it keeps unread counts authoritative (they're per-viewer)."""
    for user_id in await dm_service.participant_ids(db, channel.id):
        conversation = await dm_service.to_conversation_read(db, channel, user_id)
        if conversation is None:
            continue
        await manager.send_to_user(
            user_id,
            GatewayEvent(
                op=GatewayEventType.DM_UPDATE, data=conversation.model_dump(mode="json")
            ),
        )


async def _to_reply_preview(reply_to_id: uuid.UUID, db: DbSession) -> MessageReplyPreview | None:
    parent = await db.get(Message, reply_to_id)
    if parent is None:
        # Original was deleted (reply_to_id is SET NULL on the child by then,
        # but a race — read right as it's deleted — can still hit this).
        return None
    parent_author = await db.get(User, parent.author_id)
    has_attachments = (
        await db.execute(select(Attachment.id).where(Attachment.message_id == parent.id).limit(1))
    ).first() is not None
    return MessageReplyPreview(
        id=parent.id,
        author=UserRead.model_validate(parent_author),
        content=parent.content,
        has_attachments=has_attachments,
    )


async def _to_message_read(message: Message, db: DbSession) -> MessageRead:
    author = await db.get(User, message.author_id)
    attachments = (
        (await db.execute(select(Attachment).where(Attachment.message_id == message.id)))
        .scalars()
        .all()
    )
    reply_to = await _to_reply_preview(message.reply_to_id, db) if message.reply_to_id else None
    return MessageRead(
        id=message.id,
        channel_id=message.channel_id,
        author=UserRead.model_validate(author),
        content=message.content,
        created_at=message.created_at,
        edited_at=message.edited_at,
        attachments=[
            AttachmentRead(
                id=a.id,
                filename=a.filename,
                content_type=a.content_type,
                size_bytes=a.size_bytes,
                url=_attachment_url(a),
                created_at=a.created_at,
            )
            for a in attachments
        ],
        reply_to=reply_to,
    )


@router.get("/api/channels/{channel_id}/messages", response_model=MessagePage)
async def list_messages(
    channel_id: uuid.UUID,
    user: CurrentUser,
    db: DbSession,
    before: uuid.UUID | None = Query(default=None),
    limit: int = Query(default=50, ge=1, le=100),
) -> MessagePage:
    await _get_readable_channel_or_404(channel_id, user, db)

    query = select(Message).where(Message.channel_id == channel_id)
    if before is not None:
        cursor = await db.get(Message, before)
        if cursor is not None:
            query = query.where(Message.seq < cursor.seq)
    query = query.order_by(Message.seq.desc()).limit(limit + 1)

    rows = (await db.execute(query)).scalars().all()
    has_more = len(rows) > limit
    rows = rows[:limit]
    rows.reverse()

    return MessagePage(messages=[await _to_message_read(m, db) for m in rows], has_more=has_more)


@router.post(
    "/api/channels/{channel_id}/messages",
    response_model=MessageRead,
    status_code=status.HTTP_201_CREATED,
)
async def create_message(
    channel_id: uuid.UUID, payload: MessageCreateRequest, user: CurrentUser, db: DbSession
) -> MessageRead:
    channel = await _get_readable_channel_or_404(channel_id, user, db)

    reply_to_id: uuid.UUID | None = None
    if payload.reply_to_id is not None:
        parent = await db.get(Message, payload.reply_to_id)
        if parent is None or parent.channel_id != channel_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Message being replied to was not found in this channel",
            )
        reply_to_id = parent.id

    message = Message(
        channel_id=channel_id, author_id=user.id, content=payload.content, reply_to_id=reply_to_id
    )
    db.add(message)
    await db.flush()

    if payload.attachment_ids:
        attachments = (
            (
                await db.execute(
                    select(Attachment).where(
                        Attachment.id.in_(payload.attachment_ids),
                        Attachment.uploaded_by_id == user.id,
                        Attachment.message_id.is_(None),
                    )
                )
            )
            .scalars()
            .all()
        )
        for attachment in attachments:
            attachment.message_id = message.id
            db.add(attachment)

    await db.commit()
    await db.refresh(message)

    result = await _to_message_read(message, db)
    if channel.type == ChannelType.DM:
        # Before the message itself, so the recipient's client has somewhere to
        # put it if this is the first they've heard of the conversation.
        await _push_dm_conversation(channel, db)
    await _dispatch(
        channel,
        GatewayEvent(op=GatewayEventType.MESSAGE_CREATE, data=result.model_dump(mode="json")),
        db,
    )
    return result


async def _get_own_message_or_404(
    message_id: uuid.UUID, user: CurrentUser, db: DbSession
) -> tuple[Message, Channel]:
    message = await db.get(Message, message_id)
    if message is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Message not found")
    channel = await _get_readable_channel_or_404(message.channel_id, user, db)
    # Admins moderate the server's channels, but a DM isn't theirs to moderate —
    # inside one, only the author can touch their own message.
    may_moderate = user.is_admin and channel.type != ChannelType.DM
    if message.author_id != user.id and not may_moderate:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not allowed")
    return message, channel


@router.patch("/api/messages/{message_id}", response_model=MessageRead)
async def update_message(
    message_id: uuid.UUID, payload: MessageUpdateRequest, user: CurrentUser, db: DbSession
) -> MessageRead:
    message, channel = await _get_own_message_or_404(message_id, user, db)
    message.content = payload.content
    message.edited_at = datetime.now(UTC)
    db.add(message)
    await db.commit()
    await db.refresh(message)

    result = await _to_message_read(message, db)
    await _dispatch(
        channel,
        GatewayEvent(op=GatewayEventType.MESSAGE_UPDATE, data=result.model_dump(mode="json")),
        db,
    )
    return result


@router.delete("/api/messages/{message_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_message(message_id: uuid.UUID, user: CurrentUser, db: DbSession) -> None:
    message, channel = await _get_own_message_or_404(message_id, user, db)
    await db.delete(message)
    await db.commit()

    await _dispatch(
        channel,
        GatewayEvent(
            op=GatewayEventType.MESSAGE_DELETE,
            data={"id": str(message_id), "channel_id": str(channel.id)},
        ),
        db,
    )
    if channel.type == ChannelType.DM:
        # The deleted message may have been the conversation's last — refresh the
        # preview/unread state in both rails.
        await _push_dm_conversation(channel, db)
