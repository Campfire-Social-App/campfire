import pytest
import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

pytestmark = pytest.mark.asyncio


async def _make_member(db_session: AsyncSession, username: str):
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


@pytest_asyncio.fixture
async def alice(db_session: AsyncSession):
    return await _make_member(db_session, "alice")


@pytest_asyncio.fixture
async def bob(db_session: AsyncSession):
    return await _make_member(db_session, "bob")


async def test_open_dm_is_idempotent_in_both_directions(
    client: AsyncClient, alice, bob
) -> None:
    first = await client.post("/api/dms", json={"user_id": str(bob.id)}, headers=_headers(alice))
    assert first.status_code == 200
    assert first.json()["recipient"]["username"] == "bob"

    again = await client.post("/api/dms", json={"user_id": str(bob.id)}, headers=_headers(alice))
    assert again.json()["id"] == first.json()["id"]

    # Bob opening it from his side lands in the same conversation, seen from his POV.
    from_bob = await client.post("/api/dms", json={"user_id": str(alice.id)}, headers=_headers(bob))
    assert from_bob.json()["id"] == first.json()["id"]
    assert from_bob.json()["recipient"]["username"] == "alice"


async def test_cannot_dm_yourself(client: AsyncClient, alice) -> None:
    resp = await client.post("/api/dms", json={"user_id": str(alice.id)}, headers=_headers(alice))
    assert resp.status_code == 400


async def test_dm_is_invisible_to_outsiders(
    client: AsyncClient, alice, bob, admin_user, admin_headers: dict[str, str]
) -> None:
    dm = await client.post("/api/dms", json={"user_id": str(bob.id)}, headers=_headers(alice))
    dm_id = dm.json()["id"]

    sent = await client.post(
        f"/api/channels/{dm_id}/messages", json={"content": "just between us"}, headers=_headers(alice)
    )
    assert sent.status_code == 201

    # Bob is a participant and reads it.
    bob_view = await client.get(f"/api/channels/{dm_id}/messages", headers=_headers(bob))
    assert [m["content"] for m in bob_view.json()["messages"]] == ["just between us"]

    # The admin is not — and gets 404, not 403, so the conversation's existence
    # isn't even confirmed.
    assert (await client.get(f"/api/channels/{dm_id}/messages", headers=admin_headers)).status_code == 404
    assert (
        await client.post(
            f"/api/channels/{dm_id}/messages", json={"content": "butting in"}, headers=admin_headers
        )
    ).status_code == 404

    # And it never shows up as a server channel.
    channels = await client.get("/api/channels", headers=admin_headers)
    assert dm_id not in [c["id"] for c in channels.json()]


async def test_dm_list_reports_unread_until_read(client: AsyncClient, alice, bob) -> None:
    dm = await client.post("/api/dms", json={"user_id": str(bob.id)}, headers=_headers(alice))
    dm_id = dm.json()["id"]

    for i in range(3):
        await client.post(
            f"/api/channels/{dm_id}/messages", json={"content": f"ping {i}"}, headers=_headers(alice)
        )

    bob_list = await client.get("/api/dms", headers=_headers(bob))
    assert bob_list.status_code == 200
    conversation = next(c for c in bob_list.json() if c["id"] == dm_id)
    assert conversation["unread_count"] == 3
    assert conversation["last_message_at"] is not None

    # Your own messages never count as unread against you.
    alice_list = await client.get("/api/dms", headers=_headers(alice))
    assert next(c for c in alice_list.json() if c["id"] == dm_id)["unread_count"] == 0

    assert (await client.post(f"/api/dms/{dm_id}/read", headers=_headers(bob))).status_code == 204
    bob_list = await client.get("/api/dms", headers=_headers(bob))
    assert next(c for c in bob_list.json() if c["id"] == dm_id)["unread_count"] == 0


async def test_outsider_cannot_mark_dm_read(client: AsyncClient, alice, bob, admin_headers) -> None:
    dm = await client.post("/api/dms", json={"user_id": str(bob.id)}, headers=_headers(alice))
    resp = await client.post(f"/api/dms/{dm.json()['id']}/read", headers=admin_headers)
    assert resp.status_code == 404


async def test_admin_cannot_moderate_messages_inside_a_dm(
    client: AsyncClient, alice, bob, admin_headers: dict[str, str]
) -> None:
    dm = await client.post("/api/dms", json={"user_id": str(bob.id)}, headers=_headers(alice))
    dm_id = dm.json()["id"]
    message = await client.post(
        f"/api/channels/{dm_id}/messages", json={"content": "private"}, headers=_headers(alice)
    )
    message_id = message.json()["id"]

    assert (await client.delete(f"/api/messages/{message_id}", headers=admin_headers)).status_code == 404
    # Neither can the recipient — only the author owns their message.
    assert (await client.delete(f"/api/messages/{message_id}", headers=_headers(bob))).status_code == 403
    assert (await client.delete(f"/api/messages/{message_id}", headers=_headers(alice))).status_code == 204


async def test_dm_channels_cannot_be_created_or_deleted_as_channels(
    client: AsyncClient, alice, bob, admin_headers: dict[str, str]
) -> None:
    rejected = await client.post(
        "/api/channels", json={"name": "sneaky", "type": "dm"}, headers=admin_headers
    )
    assert rejected.status_code == 422

    dm = await client.post("/api/dms", json={"user_id": str(bob.id)}, headers=_headers(alice))
    assert (await client.delete(f"/api/channels/{dm.json()['id']}", headers=admin_headers)).status_code == 404
