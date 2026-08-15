import uuid

from fastapi import APIRouter, WebSocket, WebSocketDisconnect, status
from sqlalchemy import select

from app.core.security import InvalidTokenError, TokenType, decode_token
from app.db import async_session_maker
from app.gateway.events import GatewayEvent, GatewayEventType
from app.gateway.manager import manager
from app.models.channel import Channel, ChannelType
from app.models.server_settings import SINGLETON_ID, ServerSettings
from app.models.user import User
from app.services import dm_service

router = APIRouter()


async def _authenticate(websocket: WebSocket) -> User | None:
    token = websocket.query_params.get("token")
    if not token:
        return None
    try:
        user_id = decode_token(token, TokenType.ACCESS)
    except InvalidTokenError:
        return None

    async with async_session_maker() as db:
        return await db.get(User, user_id)


async def _build_ready_payload(user: User) -> dict:
    async with async_session_maker() as db:
        channels = (
            (
                await db.execute(
                    select(Channel)
                    .where(Channel.type != ChannelType.DM)
                    .order_by(Channel.position)
                )
            )
            .scalars()
            .all()
        )
        settings_row = await db.get(ServerSettings, SINGLETON_ID)
        dms = await dm_service.list_conversations(db, user.id)

    return {
        "user": {"id": str(user.id), "username": user.username, "is_admin": user.is_admin},
        "server": {
            "name": settings_row.name if settings_row else "Campfire",
            "icon_url": settings_row.icon_url if settings_row else None,
        },
        "channels": [
            {
                "id": str(c.id),
                "name": c.name,
                "type": c.type.value,
                "position": c.position,
            }
            for c in channels
        ],
        "dms": [d.model_dump(mode="json") for d in dms],
        "online_user_ids": [str(uid) for uid in manager.online_user_ids()],
        "voice_states": [
            {
                "user_id": str(s.user_id),
                "username": s.username,
                "channel_id": str(s.channel_id),
                "muted": s.muted,
                "speaking": s.speaking,
            }
            for s in manager.all_voice_state()
        ],
    }


async def _dispatch_typing(user: User, channel_id: str) -> None:
    """Typing in a DM must reach only the other member — the same fan-out rule the
    REST side applies to messages (see api/messages.py `_dispatch`)."""
    event = GatewayEvent(
        op=GatewayEventType.TYPING_START,
        data={"user_id": str(user.id), "channel_id": channel_id},
    )
    try:
        parsed_id = uuid.UUID(channel_id)
    except ValueError:
        return

    async with async_session_maker() as db:
        channel = await db.get(Channel, parsed_id)
        if channel is None:
            return
        if channel.type != ChannelType.DM:
            await manager.broadcast(event)
            return
        participants = await dm_service.participant_ids(db, parsed_id)

    if user.id not in participants:
        return
    for participant_id in participants:
        await manager.send_to_user(participant_id, event)


@router.websocket("/gateway")
async def gateway_endpoint(websocket: WebSocket) -> None:
    user = await _authenticate(websocket)
    if user is None:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    await manager.connect(user.id, websocket)
    try:
        ready = GatewayEvent(op=GatewayEventType.READY, data=await _build_ready_payload(user))
        await websocket.send_json(ready.model_dump(mode="json"))

        await manager.broadcast(
            GatewayEvent(
                op=GatewayEventType.PRESENCE_UPDATE,
                data={"user_id": str(user.id), "status": "online"},
            )
        )

        while True:
            message = await websocket.receive_json()
            op = message.get("op")

            if op == "HEARTBEAT":
                await websocket.send_json({"op": "HEARTBEAT_ACK"})
            elif op == "TYPING_START":
                channel_id = message.get("data", {}).get("channel_id")
                if channel_id:
                    await _dispatch_typing(user, str(channel_id))
    except WebSocketDisconnect:
        pass
    finally:
        manager.disconnect(user.id, websocket)
        if not manager.is_connected(user.id):
            await manager.broadcast(
                GatewayEvent(
                    op=GatewayEventType.PRESENCE_UPDATE,
                    data={"user_id": str(user.id), "status": "offline"},
                )
            )
