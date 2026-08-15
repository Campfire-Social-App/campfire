import uuid

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select

from app.core.deps import AdminUser, CurrentUser, DbSession
from app.gateway.events import GatewayEvent, GatewayEventType
from app.gateway.manager import manager
from app.models.channel import Channel
from app.schemas.channel import ChannelCreateRequest, ChannelRead, ChannelUpdateRequest

router = APIRouter(prefix="/api/channels", tags=["channels"])


@router.get("", response_model=list[ChannelRead])
async def list_channels(user: CurrentUser, db: DbSession) -> list[Channel]:
    result = await db.execute(select(Channel).order_by(Channel.position))
    return list(result.scalars().all())


@router.post("", response_model=ChannelRead, status_code=status.HTTP_201_CREATED)
async def create_channel(payload: ChannelCreateRequest, admin: AdminUser, db: DbSession) -> Channel:
    channel = Channel(name=payload.name, type=payload.type, position=payload.position)
    db.add(channel)
    await db.commit()
    await db.refresh(channel)

    await manager.broadcast(
        GatewayEvent(
            op=GatewayEventType.CHANNEL_CREATE,
            data=ChannelRead.model_validate(channel).model_dump(mode="json"),
        )
    )
    return channel


async def _get_channel_or_404(channel_id: uuid.UUID, db: DbSession) -> Channel:
    channel = await db.get(Channel, channel_id)
    if channel is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Canal não encontrado")
    return channel


@router.patch("/{channel_id}", response_model=ChannelRead)
async def update_channel(
    channel_id: uuid.UUID, payload: ChannelUpdateRequest, admin: AdminUser, db: DbSession
) -> Channel:
    channel = await _get_channel_or_404(channel_id, db)
    if payload.name is not None:
        channel.name = payload.name
    if payload.position is not None:
        channel.position = payload.position
    db.add(channel)
    await db.commit()
    await db.refresh(channel)

    await manager.broadcast(
        GatewayEvent(
            op=GatewayEventType.CHANNEL_UPDATE,
            data=ChannelRead.model_validate(channel).model_dump(mode="json"),
        )
    )
    return channel


@router.delete("/{channel_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_channel(channel_id: uuid.UUID, admin: AdminUser, db: DbSession) -> None:
    channel = await _get_channel_or_404(channel_id, db)
    await db.delete(channel)
    await db.commit()

    await manager.broadcast(
        GatewayEvent(op=GatewayEventType.CHANNEL_DELETE, data={"id": str(channel_id)})
    )
