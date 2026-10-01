from fastapi import APIRouter, status

from app.core.deps import CurrentUser, DbSession
from app.schemas.audio_event import AudioEventBatchIn
from app.services.audio_event_service import MAX_EVENTS_PER_BATCH, record_audio_event

router = APIRouter(prefix="/api/diagnostics", tags=["diagnostics"])


@router.post("/audio-events", status_code=status.HTTP_204_NO_CONTENT)
async def ingest_audio_events(
    payload: AudioEventBatchIn, user: CurrentUser, db: DbSession
) -> None:
    for event in payload.events[:MAX_EVENTS_PER_BATCH]:
        await record_audio_event(
            db,
            source="client",
            event_type=event.event_type,
            user_id=user.id,
            channel_id=event.channel_id,
            session_id=event.session_id,
            platform=event.platform,
            detail=event.detail,
            client_ts=event.client_ts,
        )
