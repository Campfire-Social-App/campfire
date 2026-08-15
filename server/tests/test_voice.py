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


async def _make_member(db_session, username: str):
    from app.core.security import hash_password
    from app.models.user import User

    user = User(username=username, password_hash=hash_password("password123"))
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


def _headers(user) -> dict[str, str]:
    from app.core.security import create_access_token

    return {"Authorization": f"Bearer {create_access_token(user.id)}"}


async def test_voice_token_for_dm_call(client: AsyncClient, db_session) -> None:
    """A DM is a room too — its two members can get a token for it, which is what
    makes a 1:1 call possible without a voice channel."""
    alice = await _make_member(db_session, "voice-alice")
    bob = await _make_member(db_session, "voice-bob")
    dm = await client.post("/api/dms", json={"user_id": str(bob.id)}, headers=_headers(alice))
    dm_id = dm.json()["id"]

    for member in (alice, bob):
        resp = await client.post(f"/api/voice/{dm_id}/token", headers=_headers(member))
        assert resp.status_code == 200
        assert resp.json()["room"] == dm_id


async def test_voice_token_hides_a_dm_from_outsiders(
    client: AsyncClient, db_session, admin_headers: dict[str, str]
) -> None:
    alice = await _make_member(db_session, "voice-carol")
    bob = await _make_member(db_session, "voice-dave")
    dm = await client.post("/api/dms", json={"user_id": str(bob.id)}, headers=_headers(alice))

    resp = await client.post(f"/api/voice/{dm.json()['id']}/token", headers=admin_headers)
    assert resp.status_code == 404
