import pytest
from httpx import AsyncClient
from sqlalchemy import select

from app.models.audio_event import AudioEvent

pytestmark = pytest.mark.asyncio


async def test_ingest_audio_events_persists_rows(
    client: AsyncClient, admin_headers: dict[str, str], db_session
) -> None:
    resp = await client.post(
        "/api/diagnostics/audio-events",
        json={
            "events": [
                {"platform": "web", "event_type": "mic_enable_failed", "detail": {"error": "NotAllowedError"}},
                {"platform": "web", "event_type": "mic_enable_succeeded", "detail": {}},
            ]
        },
        headers=admin_headers,
    )
    assert resp.status_code == 204

    rows = (await db_session.execute(select(AudioEvent))).scalars().all()
    assert len(rows) == 2
    assert {row.event_type for row in rows} == {"mic_enable_failed", "mic_enable_succeeded"}
    assert all(row.source == "client" for row in rows)
    assert all(row.platform == "web" for row in rows)


async def test_ingest_audio_events_empty_batch_persists_nothing(
    client: AsyncClient, admin_headers: dict[str, str], db_session
) -> None:
    resp = await client.post(
        "/api/diagnostics/audio-events", json={"events": []}, headers=admin_headers
    )
    assert resp.status_code == 204

    rows = (await db_session.execute(select(AudioEvent))).scalars().all()
    assert rows == []


async def test_ingest_audio_events_caps_batch_size(
    client: AsyncClient, admin_headers: dict[str, str], db_session
) -> None:
    events = [{"platform": "web", "event_type": "room_reconnecting"} for _ in range(80)]
    resp = await client.post(
        "/api/diagnostics/audio-events", json={"events": events}, headers=admin_headers
    )
    assert resp.status_code == 204

    rows = (await db_session.execute(select(AudioEvent))).scalars().all()
    assert len(rows) == 50


async def test_ingest_audio_events_requires_auth(client: AsyncClient) -> None:
    resp = await client.post(
        "/api/diagnostics/audio-events",
        json={"events": [{"platform": "web", "event_type": "mic_enable_failed"}]},
    )
    assert resp.status_code == 401
