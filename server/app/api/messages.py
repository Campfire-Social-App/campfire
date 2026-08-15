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
from app.schemas.message import MessageCreateRequest, MessagePage, MessageRead, MessageUpdateRequest
from app.schemas.user import UserRead

router = APIRouter(tags=["messages"])


def _attachment_url(attachment: Attachment) -> str:
    return f"/uploads/{attachment.storage_path}"


async def _get_text_channel_or_404(channel_id: uuid.UUID, db: DbSession) -> Channel:
    channel = await db.get(Channel, channel_id)
    if channel is None or channel.type != ChannelType.TEXT:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Canal de texto não encontrado")
    return channel


async def _to_message_read(message: Message, db: DbSession) -> MessageRead:
    author = await db.get(User, message.author_id)
    attachments = (
        (await db.execute(select(Attachment).where(Attachment.message_id == message.id)))
        .scalars()
        .all()
    )
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
    )


@router.get("/api/channels/{channel_id}/messages", response_model=MessagePage)
async def list_messages(
    channel_id: uuid.UUID,
    user: CurrentUser,
    db: DbSession,
    before: uuid.UUID | None = Query(default=None),
    limit: int = Query(default=50, ge=1, le=100),
) -> MessagePage:
    await _get_text_channel_or_404(channel_id, db)

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
    await _get_text_channel_or_404(channel_id, db)

    message = Message(channel_id=channel_id, author_id=user.id, content=payload.content)
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
    await manager.broadcast(
        GatewayEvent(op=GatewayEventType.MESSAGE_CREATE, data=result.model_dump(mode="json"))
    )
    return result


async def _get_own_message_or_404(message_id: uuid.UUID, user: CurrentUser, db: DbSession) -> Message:
    message = await db.get(Message, message_id)
    if message is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Mensagem não encontrada")
    if message.author_id != user.id and not user.is_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Sem permissão")
    return message


@router.patch("/api/messages/{message_id}", response_model=MessageRead)
async def update_message(
    message_id: uuid.UUID, payload: MessageUpdateRequest, user: CurrentUser, db: DbSession
) -> MessageRead:
    message = await _get_own_message_or_404(message_id, user, db)
    message.content = payload.content
    message.edited_at = datetime.now(UTC)
    db.add(message)
    await db.commit()
    await db.refresh(message)

    result = await _to_message_read(message, db)
    await manager.broadcast(
        GatewayEvent(op=GatewayEventType.MESSAGE_UPDATE, data=result.model_dump(mode="json"))
    )
    return result


@router.delete("/api/messages/{message_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_message(message_id: uuid.UUID, user: CurrentUser, db: DbSession) -> None:
    message = await _get_own_message_or_404(message_id, user, db)
    channel_id = message.channel_id
    await db.delete(message)
    await db.commit()

    await manager.broadcast(
        GatewayEvent(
            op=GatewayEventType.MESSAGE_DELETE,
            data={"id": str(message_id), "channel_id": str(channel_id)},
        )
    )
