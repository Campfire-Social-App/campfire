import pytest
from httpx import AsyncClient

pytestmark = pytest.mark.asyncio


async def test_voice_token_for_voice_channel(client: AsyncClient, admin_headers: dict[str, str]) -> None:
    resp = await client.post(
        "/api/channels", json={"name": "voz-geral", "type": "voice"}, headers=admin_headers
    )
    channel_id = resp.json()["id"]

    token_resp = await client.post(f"/api/voice/{channel_id}/token", headers=admin_headers)
    assert token_resp.status_code == 200
    body = token_resp.json()
    assert body["room"] == channel_id
    assert body["token"]
    assert body["url"]


async def test_voice_token_rejects_text_channel(client: AsyncClient, admin_headers: dict[str, str]) -> None:
    resp = await client.post(
        "/api/channels", json={"name": "geral", "type": "text"}, headers=admin_headers
    )
    channel_id = resp.json()["id"]

    token_resp = await client.post(f"/api/voice/{channel_id}/token", headers=admin_headers)
    assert token_resp.status_code == 404


async def test_voice_token_rejects_unknown_channel(
    client: AsyncClient, admin_headers: dict[str, str]
) -> None:
    resp = await client.post(
        "/api/voice/00000000-0000-0000-0000-000000000000/token", headers=admin_headers
    )
    assert resp.status_code == 404
