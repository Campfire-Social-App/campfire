import uuid

from fastapi import APIRouter, HTTPException, status

from app.core.config import get_settings
from app.core.deps import CurrentUser, DbSession
from app.models.channel import Channel, ChannelType
from app.schemas.voice import VoiceTokenResponse
from app.services.livekit_service import create_voice_token

router = APIRouter(prefix="/api/voice", tags=["voice"])


@router.post("/{channel_id}/token", response_model=VoiceTokenResponse)
async def get_voice_token(channel_id: uuid.UUID, user: CurrentUser, db: DbSession) -> VoiceTokenResponse:
    channel = await db.get(Channel, channel_id)
    if channel is None or channel.type != ChannelType.VOICE:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Canal de voz não encontrado")

    settings = get_settings()
    room = str(channel.id)
    token = create_voice_token(room=room, identity=str(user.id), name=user.username)
    return VoiceTokenResponse(token=token, url=settings.livekit_url, room=room)
