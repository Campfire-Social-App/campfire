import uuid
from datetime import UTC, datetime

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.channel import Channel, ChannelType
from app.models.dm import DMParticipant
from app.models.message import Message
from app.models.user import User
from app.schemas.dm import DMConversationRead
from app.schemas.user import UserRead

# Sort placeholder for a conversation with no messages yet — later than any
# real timestamp, so an empty DM stays pinned at the top of the list.
_NEVER_STALE = datetime.max.replace(tzinfo=UTC)


def dm_key_for(user_a: uuid.UUID, user_b: uuid.UUID) -> str:
    """Order-independent identity for a pair — see Channel.dm_key."""
    return ":".join(sorted([str(user_a), str(user_b)]))


async def get_or_create_dm(db: AsyncSession, user_a: uuid.UUID, user_b: uuid.UUID) -> Channel:
    key = dm_key_for(user_a, user_b)
    existing = (
        await db.execute(select(Channel).where(Channel.dm_key == key))
    ).scalar_one_or_none()
    if existing is not None:
        return existing

    channel = Channel(name="", type=ChannelType.DM, dm_key=key)
    db.add(channel)
    try:
        await db.flush()
        db.add_all(
            [
                DMParticipant(channel_id=channel.id, user_id=user_a),
                DMParticipant(channel_id=channel.id, user_id=user_b),
            ]
        )
        await db.commit()
    except IntegrityError:
        # The other side of the pair created the same conversation between our
        # SELECT and INSERT — the dm_key unique index caught it. Theirs wins.
        await db.rollback()
        return (await db.execute(select(Channel).where(Channel.dm_key == key))).scalar_one()

    await db.refresh(channel)
    return channel


async def participant_ids(db: AsyncSession, channel_id: uuid.UUID) -> list[uuid.UUID]:
    rows = await db.execute(
        select(DMParticipant.user_id).where(DMParticipant.channel_id == channel_id)
    )
    return list(rows.scalars().all())


async def is_participant(db: AsyncSession, channel_id: uuid.UUID, user_id: uuid.UUID) -> bool:
    row = await db.execute(
        select(DMParticipant.user_id).where(
            DMParticipant.channel_id == channel_id, DMParticipant.user_id == user_id
        )
    )
    return row.first() is not None


async def mark_read(db: AsyncSession, channel_id: uuid.UUID, user_id: uuid.UUID) -> None:
    participant = await db.get(DMParticipant, (channel_id, user_id))
    if participant is None:
        return
    participant.last_read_at = func.now()
    db.add(participant)
    await db.commit()


async def to_conversation_read(
    db: AsyncSession, channel: Channel, viewer_id: uuid.UUID
) -> DMConversationRead | None:
    """Renders `channel` from `viewer_id`'s point of view. Returns None when the
    other member is gone (their account was deleted), which makes the
    conversation unrenderable rather than an error to propagate."""
    recipient = (
        await db.execute(
            select(User)
            .join(DMParticipant, DMParticipant.user_id == User.id)
            .where(DMParticipant.channel_id == channel.id, DMParticipant.user_id != viewer_id)
            .limit(1)
        )
    ).scalar_one_or_none()
    if recipient is None:
        return None

    last_message_at = (
        await db.execute(
            select(func.max(Message.created_at)).where(Message.channel_id == channel.id)
        )
    ).scalar_one()

    viewer = await db.get(DMParticipant, (channel.id, viewer_id))
    unread_query = select(func.count(Message.id)).where(
        Message.channel_id == channel.id, Message.author_id != viewer_id
    )
    if viewer is not None and viewer.last_read_at is not None:
        unread_query = unread_query.where(Message.created_at > viewer.last_read_at)
    unread_count = (await db.execute(unread_query)).scalar_one()

    return DMConversationRead(
        id=channel.id,
        recipient=UserRead.model_validate(recipient),
        last_message_at=last_message_at,
        unread_count=unread_count,
    )


async def list_conversations(db: AsyncSession, viewer_id: uuid.UUID) -> list[DMConversationRead]:
    channels = (
        (
            await db.execute(
                select(Channel)
                .join(DMParticipant, DMParticipant.channel_id == Channel.id)
                .where(Channel.type == ChannelType.DM, DMParticipant.user_id == viewer_id)
            )
        )
        .scalars()
        .all()
    )
    conversations = [await to_conversation_read(db, c, viewer_id) for c in channels]
    # Most recently active first; a conversation with no messages yet (just
    # opened, nothing sent) sorts to the top, where the user left it.
    return sorted(
        (c for c in conversations if c is not None),
        key=lambda c: c.last_message_at or _NEVER_STALE,
        reverse=True,
    )
