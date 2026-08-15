import pytest
from httpx import AsyncClient

pytestmark = pytest.mark.asyncio


async def _create_text_channel(client: AsyncClient, admin_headers: dict[str, str]) -> str:
    resp = await client.post(
        "/api/channels", json={"name": "geral", "type": "text"}, headers=admin_headers
    )
    assert resp.status_code == 201
    return resp.json()["id"]


async def test_message_pagination(client: AsyncClient, admin_headers: dict[str, str]) -> None:
    channel_id = await _create_text_channel(client, admin_headers)

    for i in range(5):
        resp = await client.post(
            f"/api/channels/{channel_id}/messages",
            json={"content": f"message {i}"},
            headers=admin_headers,
        )
        assert resp.status_code == 201

    # No cursor -> most recent page, oldest-to-newest within that page (like opening a chat).
    page1 = await client.get(
        f"/api/channels/{channel_id}/messages", params={"limit": 2}, headers=admin_headers
    )
    assert page1.status_code == 200
    page1_body = page1.json()
    assert page1_body["has_more"] is True
    assert [m["content"] for m in page1_body["messages"]] == ["message 3", "message 4"]

    # Scrolling up: "before" the oldest message currently shown loads the previous page.
    cursor = page1_body["messages"][0]["id"]
    page2 = await client.get(
        f"/api/channels/{channel_id}/messages",
        params={"limit": 2, "before": cursor},
        headers=admin_headers,
    )
    assert page2.status_code == 200
    page2_body = page2.json()
    assert page2_body["has_more"] is True
    assert [m["content"] for m in page2_body["messages"]] == ["message 1", "message 2"]

    cursor2 = page2_body["messages"][0]["id"]
    page3 = await client.get(
        f"/api/channels/{channel_id}/messages",
        params={"limit": 2, "before": cursor2},
        headers=admin_headers,
    )
    assert page3.status_code == 200
    page3_body = page3.json()
    assert page3_body["has_more"] is False
    assert [m["content"] for m in page3_body["messages"]] == ["message 0"]

    all_msgs = await client.get(
        f"/api/channels/{channel_id}/messages", params={"limit": 50}, headers=admin_headers
    )
    assert len(all_msgs.json()["messages"]) == 5
    assert all_msgs.json()["has_more"] is False


async def test_edit_and_delete_message_requires_ownership(
    client: AsyncClient, admin_headers: dict[str, str]
) -> None:
    channel_id = await _create_text_channel(client, admin_headers)

    invite_resp = await client.post("/api/invites", json={"max_uses": 1}, headers=admin_headers)
    code = invite_resp.json()["code"]
    register_resp = await client.post(
        "/api/auth/register",
        json={"invite_code": code, "username": "friend1", "password": "friendpass1"},
    )
    friend_headers = {"Authorization": f"Bearer {register_resp.json()['access_token']}"}

    create_resp = await client.post(
        f"/api/channels/{channel_id}/messages",
        json={"content": "original"},
        headers=admin_headers,
    )
    message_id = create_resp.json()["id"]

    forbidden = await client.patch(
        f"/api/messages/{message_id}", json={"content": "hacked"}, headers=friend_headers
    )
    assert forbidden.status_code == 403

    ok = await client.patch(
        f"/api/messages/{message_id}", json={"content": "edited"}, headers=admin_headers
    )
    assert ok.status_code == 200
    assert ok.json()["content"] == "edited"
    assert ok.json()["edited_at"] is not None

    delete_resp = await client.delete(f"/api/messages/{message_id}", headers=admin_headers)
    assert delete_resp.status_code == 204


async def test_reply_to_message(client: AsyncClient, admin_headers: dict[str, str]) -> None:
    channel_id = await _create_text_channel(client, admin_headers)

    original = await client.post(
        f"/api/channels/{channel_id}/messages",
        json={"content": "original message"},
        headers=admin_headers,
    )
    original_id = original.json()["id"]

    reply = await client.post(
        f"/api/channels/{channel_id}/messages",
        json={"content": "a reply", "reply_to_id": original_id},
        headers=admin_headers,
    )
    assert reply.status_code == 201
    reply_body = reply.json()
    assert reply_body["reply_to"]["id"] == original_id
    assert reply_body["reply_to"]["content"] == "original message"
    assert reply_body["reply_to"]["has_attachments"] is False

    # Deleting the original severs the link (SET NULL) rather than cascading
    # to delete the reply too.
    await client.delete(f"/api/messages/{original_id}", headers=admin_headers)
    page = await client.get(f"/api/channels/{channel_id}/messages", headers=admin_headers)
    messages = page.json()["messages"]
    assert [m["content"] for m in messages] == ["a reply"]
    assert messages[0]["reply_to"] is None


async def test_reply_to_message_in_another_channel_rejected(
    client: AsyncClient, admin_headers: dict[str, str]
) -> None:
    channel_a = await _create_text_channel(client, admin_headers)
    channel_b_resp = await client.post(
        "/api/channels", json={"name": "outro", "type": "text"}, headers=admin_headers
    )
    channel_b = channel_b_resp.json()["id"]

    original = await client.post(
        f"/api/channels/{channel_a}/messages", json={"content": "hi"}, headers=admin_headers
    )
    original_id = original.json()["id"]

    resp = await client.post(
        f"/api/channels/{channel_b}/messages",
        json={"content": "cross-channel reply", "reply_to_id": original_id},
        headers=admin_headers,
    )
    assert resp.status_code == 400


async def test_cannot_post_message_to_voice_channel(
    client: AsyncClient, admin_headers: dict[str, str]
) -> None:
    resp = await client.post(
        "/api/channels", json={"name": "voz", "type": "voice"}, headers=admin_headers
    )
    channel_id = resp.json()["id"]

    post_resp = await client.post(
        f"/api/channels/{channel_id}/messages", json={"content": "oi"}, headers=admin_headers
    )
    assert post_resp.status_code == 404
