import uuid
from datetime import datetime

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.audio_event import AudioEvent

# A client stuck in a retry/error loop should not be able to turn one bug
# into an unbounded number of rows.
MAX_EVENTS_PER_BATCH = 50


async def record_audio_event(
    db: AsyncSession,
    *,
    source: str,
    event_type: str,
    user_id: uuid.UUID | None = None,
    channel_id: uuid.UUID | None = None,
    session_id: uuid.UUID | None = None,
    platform: str | None = None,
    detail: dict | None = None,
    client_ts: datetime | None = None,
) -> None:
    db.add(
        AudioEvent(
            source=source,
            event_type=event_type,
            user_id=user_id,
            channel_id=channel_id,
            session_id=session_id,
            platform=platform,
            detail=detail or {},
            client_ts=client_ts,
        )
    )
    await db.commit()
