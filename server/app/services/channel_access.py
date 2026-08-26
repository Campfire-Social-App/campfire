import uuid

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.channel import Channel, ChannelType
from app.models.user import User
from app.services import dm_service


async def readable_channel_or_404(
    channel_id: uuid.UUID, user: User, db: AsyncSession
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
