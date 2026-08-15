import uuid

from fastapi import APIRouter, HTTPException, status

from app.core.config import get_settings
from app.core.deps import CurrentUser, DbSession
from app.models.channel import Channel, ChannelType
from app.schemas.voice import VoiceTokenResponse
from app.services import dm_service
from app.services.livekit_service import create_voice_token

router = APIRouter(prefix="/api/voice", tags=["voice"])


@router.post("/{channel_id}/token", response_model=VoiceTokenResponse)
async def get_voice_token(channel_id: uuid.UUID, user: CurrentUser, db: DbSession) -> VoiceTokenResponse:
    """Mints a LiveKit token for a room. Two kinds of room qualify: a voice
    channel (open to every member) and a DM (a 1:1 call — only its two members,
    and an outsider gets 404 rather than 403, matching the DM message routes)."""
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
