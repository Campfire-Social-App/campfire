import logging
import uuid

from fastapi import APIRouter, Header, HTTPException, Request, status

from app.db import async_session_maker
from app.gateway.events import GatewayEvent, GatewayEventType
from app.gateway.manager import VoiceParticipantState, manager
from app.models.channel import Channel, ChannelType
from app.services import dm_service
from app.services.livekit_service import get_webhook_receiver

router = APIRouter(prefix="/api/webhooks", tags=["webhooks"])
logger = logging.getLogger(__name__)


async def _dispatch_voice_event(channel_id: uuid.UUID | None, event: GatewayEvent) -> None:
    """Who is in a voice channel is public to the whole server; who is on a DM
    call is not — that goes only to the conversation's two members."""
    if channel_id is not None:
        async with async_session_maker() as db:
            channel = await db.get(Channel, channel_id)
            if channel is not None and channel.type == ChannelType.DM:
                for user_id in await dm_service.participant_ids(db, channel_id):
                    await manager.send_to_user(user_id, event)
                return
    await manager.broadcast(event)


@router.post("/livekit", status_code=status.HTTP_204_NO_CONTENT)
async def livekit_webhook(request: Request, authorization: str = Header(default="")) -> None:
    body = await request.body()
    try:
        event = get_webhook_receiver().receive(body.decode("utf-8"), authorization)
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid webhook") from exc

    if event.event == "participant_joined":
        try:
            user_id = uuid.UUID(event.participant.identity)
            channel_id = uuid.UUID(event.room.name)
        except ValueError:
            logger.warning("Ignoring participant_joined with non-UUID identity/room")
            return

        # LiveKit already carries the username as the participant's display name
        # (set from the access token minted in services/livekit_service.py), so no
        # DB lookup is needed here to tell clients who joined.
        username = event.participant.name or str(user_id)
        manager.voice_state[user_id] = VoiceParticipantState(
            user_id=user_id, channel_id=channel_id, username=username
        )
        await _dispatch_voice_event(
            channel_id,
            GatewayEvent(
                op=GatewayEventType.VOICE_STATE_UPDATE,
                data={
                    "action": "joined",
                    "user_id": str(user_id),
                    "username": username,
                    "channel_id": str(channel_id),
                },
            ),
        )

    elif event.event == "participant_left":
        try:
            user_id = uuid.UUID(event.participant.identity)
        except ValueError:
            return

        state = manager.voice_state.pop(user_id, None)
        channel_id = state.channel_id if state else None
        await _dispatch_voice_event(
            channel_id,
            GatewayEvent(
                op=GatewayEventType.VOICE_STATE_UPDATE,
                data={
                    "action": "left",
                    "user_id": str(user_id),
                    "channel_id": str(channel_id) if channel_id else None,
                },
            ),
        )

    elif event.event == "room_finished":
        try:
            channel_id = uuid.UUID(event.room.name)
        except ValueError:
            return

        stale = [uid for uid, s in manager.voice_state.items() if s.channel_id == channel_id]
        for uid in stale:
            manager.voice_state.pop(uid, None)
        await _dispatch_voice_event(
            channel_id,
            GatewayEvent(
                op=GatewayEventType.VOICE_STATE_UPDATE,
                data={"action": "room_finished", "channel_id": str(channel_id)},
            ),
        )

    return
