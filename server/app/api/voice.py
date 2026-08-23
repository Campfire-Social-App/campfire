import uuid

from fastapi import APIRouter, HTTPException, status

from app.core.config import get_settings
from app.core.deps import AdminUser, CurrentUser, DbSession, require_not_timed_out
from app.gateway.events import GatewayEvent, GatewayEventType
from app.gateway.manager import manager
from app.models.channel import Channel, ChannelType
from app.schemas.voice import MoveVoiceParticipantRequest, VoiceTokenResponse
from app.services import dm_service
from app.services.livekit_service import (
    create_voice_token,
    mute_participant_microphone,
    request_participant_move,
)

router = APIRouter(prefix="/api/voice", tags=["voice"])


@router.post("/{channel_id}/token", response_model=VoiceTokenResponse)
async def get_voice_token(channel_id: uuid.UUID, user: CurrentUser, db: DbSession) -> VoiceTokenResponse:
    """Mints a LiveKit token for a room. Two kinds of room qualify: a voice
    channel (open to every member) and a DM (a 1:1 call — only its two members,
    and an outsider gets 404 rather than 403, matching the DM message routes)."""
    require_not_timed_out(user)
    channel = await db.get(Channel, channel_id)
    if channel is None or channel.type == ChannelType.TEXT:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Voice channel not found")
    if channel.type == ChannelType.DM and not await dm_service.is_participant(
        db, channel.id, user.id
    ):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Voice channel not found")

    settings = get_settings()
    room = str(channel.id)
    token = create_voice_token(room=room, identity=str(user.id), name=user.username)
    return VoiceTokenResponse(token=token, url=settings.livekit_url, room=room)


async def _voice_participant_or_404(user_id: uuid.UUID):
    participant = manager.voice_state.get(user_id)
    if participant is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Participant is not in voice")
    return participant


@router.post("/participants/{user_id}/move", status_code=status.HTTP_204_NO_CONTENT)
async def move_voice_participant(
    user_id: uuid.UUID,
    payload: MoveVoiceParticipantRequest,
    _admin: AdminUser,
    db: DbSession,
) -> None:
    participant = await _voice_participant_or_404(user_id)
    destination = await db.get(Channel, payload.channel_id)
    if destination is None or destination.type != ChannelType.VOICE:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Voice channel not found")
    if participant.channel_id == destination.id:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Participant is already there")
    # LiveKit 1.13 exposes MoveParticipant but responds "not implemented". A
    # reliable targeted data packet uses the participant's already-active media
    # connection and asks their client to join the destination with a fresh token.
    try:
        await request_participant_move(
            identity=str(user_id),
            source_room=str(participant.channel_id),
            destination_room=str(destination.id),
            destination_name=destination.name,
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="LiveKit could not move the participant",
        ) from exc


@router.post("/participants/{user_id}/mute", status_code=status.HTTP_204_NO_CONTENT)
async def mute_voice_participant(user_id: uuid.UUID, _admin: AdminUser) -> None:
    participant = await _voice_participant_or_404(user_id)
    try:
        await mute_participant_microphone(identity=str(user_id), room=str(participant.channel_id))
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="LiveKit could not mute the participant",
        ) from exc
    participant.muted = True
    await manager.broadcast(
        GatewayEvent(
            op=GatewayEventType.VOICE_STATE_UPDATE,
            data={
                "action": "updated",
                "user_id": str(user_id),
                "channel_id": str(participant.channel_id),
                "muted": True,
            },
        )
    )
