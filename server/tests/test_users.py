import pytest
from httpx import AsyncClient

pytestmark = pytest.mark.asyncio


async def test_list_users_includes_all_members(client: AsyncClient, admin_headers: dict[str, str]) -> None:
    invite_resp = await client.post("/api/invites", json={"max_uses": 1}, headers=admin_headers)
    code = invite_resp.json()["code"]
    await client.post(
        "/api/auth/register",
        json={"invite_code": code, "username": "friend1", "password": "friendpass1"},
    )

    resp = await client.get("/api/users", headers=admin_headers)
    assert resp.status_code == 200
    usernames = {u["username"] for u in resp.json()}
    assert usernames == {"admin", "friend1"}


async def test_list_users_requires_auth(client: AsyncClient) -> None:
    resp = await client.get("/api/users")
    assert resp.status_code == 401


async def test_user_can_update_profile_photo(
    client: AsyncClient, admin_headers: dict[str, str], admin_user, db_session
) -> None:
    from app.models.attachment import Attachment

    attachment = Attachment(
        uploaded_by_id=admin_user.id,
        filename="avatar.gif",
        content_type="image/gif",
        size_bytes=256,
        storage_path="avatar.gif",
    )
    db_session.add(attachment)
    await db_session.commit()
    await db_session.refresh(attachment)

    response = await client.put(
        "/api/users/@me/avatar",
        json={"attachment_id": str(attachment.id)},
        headers=admin_headers,
    )
    assert response.status_code == 200, response.text
    assert response.json()["avatar_url"] == f"/api/uploads/{attachment.id}"


async def test_user_can_update_avatar_and_profile_background_separately(
    client: AsyncClient, admin_headers: dict[str, str], admin_user, db_session
) -> None:
    from app.models.attachment import Attachment

    avatar = Attachment(
        uploaded_by_id=admin_user.id,
        filename="avatar.webp",
        content_type="image/webp",
        size_bytes=256,
        storage_path="avatar.webp",
    )
    banner = Attachment(
        uploaded_by_id=admin_user.id,
        filename="banner.gif",
        content_type="image/gif",
        size_bytes=8 * 1024 * 1024,
        storage_path="banner.gif",
    )
    db_session.add_all([avatar, banner])
    await db_session.commit()
    await db_session.refresh(avatar)
    await db_session.refresh(banner)

    avatar_response = await client.put(
        "/api/users/@me/avatar",
        json={"attachment_id": str(avatar.id)},
        headers=admin_headers,
    )
    response = await client.put(
        "/api/users/@me/banner",
        json={"attachment_id": str(banner.id)},
        headers=admin_headers,
    )

    assert avatar_response.status_code == 200, avatar_response.text
    assert response.status_code == 200, response.text
    assert response.json()["avatar_url"] == f"/api/uploads/{avatar.id}"
    assert response.json()["banner_url"] == f"/api/uploads/{banner.id}"


async def test_profile_image_larger_than_eight_megabytes_is_rejected(
    client: AsyncClient, admin_headers: dict[str, str], admin_user, db_session
) -> None:
    from app.models.attachment import Attachment

    banner = Attachment(
        uploaded_by_id=admin_user.id,
        filename="oversized.gif",
        content_type="image/gif",
        size_bytes=8 * 1024 * 1024 + 1,
        storage_path="oversized.gif",
    )
    db_session.add(banner)
    await db_session.commit()
    await db_session.refresh(banner)

    response = await client.put(
        "/api/users/@me/banner",
        json={"attachment_id": str(banner.id)},
        headers=admin_headers,
    )

    assert response.status_code == 413
    assert response.json()["detail"] == "Profile image exceeds 8 MB"


async def test_admin_moderation_overview_contains_public_history_but_not_dms(
    client: AsyncClient, admin_headers: dict[str, str], admin_user, db_session
) -> None:
    from app.core.security import create_access_token, hash_password
    from app.models.user import User

    member = User(username="history-member", password_hash=hash_password("password123"))
    db_session.add(member)
    await db_session.commit()
    await db_session.refresh(member)
    member_headers = {"Authorization": f"Bearer {create_access_token(member.id)}"}

    public_channel = await client.post(
        "/api/channels", json={"name": "public", "type": "text"}, headers=admin_headers
    )
    await client.post(
        f"/api/channels/{public_channel.json()['id']}/messages",
        json={"content": "public evidence https://example.com"},
        headers=member_headers,
    )
    dm = await client.post(
        "/api/dms", json={"user_id": str(admin_user.id)}, headers=member_headers
    )
    await client.post(
        f"/api/channels/{dm.json()['id']}/messages",
        json={"content": "private evidence"},
        headers=member_headers,
    )

    response = await client.get(f"/api/users/{member.id}/moderation", headers=admin_headers)
    assert response.status_code == 200, response.text
    assert [message["content"] for message in response.json()["messages"]] == [
        "public evidence https://example.com"
    ]
    assert response.json()["messages"][0]["channel_name"] == "public"


async def test_member_cannot_open_moderation_overview(
    client: AsyncClient, admin_user, db_session
) -> None:
    from app.core.security import create_access_token, hash_password
    from app.models.user import User

    member = User(username="regular-member", password_hash=hash_password("password123"))
    db_session.add(member)
    await db_session.commit()
    await db_session.refresh(member)

    response = await client.get(
        f"/api/users/{admin_user.id}/moderation",
        headers={"Authorization": f"Bearer {create_access_token(member.id)}"},
    )
    assert response.status_code == 403


async def test_admin_can_timeout_member_and_block_messages_and_voice(
    client: AsyncClient, admin_headers: dict[str, str], db_session
) -> None:
    from app.core.security import create_access_token, hash_password
    from app.models.user import User

    member = User(username="timeout-member", password_hash=hash_password("password123"))
    db_session.add(member)
    await db_session.commit()
    await db_session.refresh(member)
    member_headers = {"Authorization": f"Bearer {create_access_token(member.id)}"}

    text_channel = await client.post(
        "/api/channels", json={"name": "general", "type": "text"}, headers=admin_headers
    )
    voice_channel = await client.post(
        "/api/channels", json={"name": "voice", "type": "voice"}, headers=admin_headers
    )

    response = await client.post(f"/api/users/{member.id}/timeout", headers=admin_headers)
    assert response.status_code == 200, response.text
    assert response.json()["timed_out_until"] is not None

    message_response = await client.post(
        f"/api/channels/{text_channel.json()['id']}/messages",
        json={"content": "should not be sent"},
        headers=member_headers,
    )
    voice_response = await client.post(
        f"/api/voice/{voice_channel.json()['id']}/token", headers=member_headers
    )
    assert message_response.status_code == 403
    assert voice_response.status_code == 403


async def test_admin_can_ban_member_and_prevent_login(
    client: AsyncClient, admin_headers: dict[str, str], db_session
) -> None:
    from app.core.security import hash_password
    from app.models.user import User

    member = User(username="ban-member", password_hash=hash_password("password123"))
    db_session.add(member)
    await db_session.commit()
    await db_session.refresh(member)

    response = await client.post(f"/api/users/{member.id}/ban", headers=admin_headers)
    assert response.status_code == 200, response.text
    assert response.json()["is_banned"] is True

    login_response = await client.post(
        "/api/auth/login", json={"username": member.username, "password": "password123"}
    )
    assert login_response.status_code == 403


async def test_admin_can_kick_member_from_voice(
    client: AsyncClient, admin_headers: dict[str, str], db_session, monkeypatch
) -> None:
    from app.core.security import hash_password
    from app.gateway.manager import VoiceParticipantState, manager
    from app.models.channel import Channel, ChannelType
    from app.models.user import User

    member = User(username="voice-member", password_hash=hash_password("password123"))
    channel = Channel(name="Lounge", type=ChannelType.VOICE)
    db_session.add_all([member, channel])
    await db_session.commit()
    await db_session.refresh(member)
    await db_session.refresh(channel)
    manager.voice_state[member.id] = VoiceParticipantState(
        user_id=member.id,
        channel_id=channel.id,
        username=member.username,
    )
    disconnected: dict[str, str] = {}

    async def fake_disconnect_participant(*, identity: str, room: str) -> None:
        disconnected.update(identity=identity, room=room)

    monkeypatch.setattr("app.api.users.disconnect_participant", fake_disconnect_participant)
    try:
        response = await client.post(f"/api/users/{member.id}/kick", headers=admin_headers)
    finally:
        manager.voice_state.pop(member.id, None)

    assert response.status_code == 204, response.text
    assert disconnected == {"identity": str(member.id), "room": str(channel.id)}


async def test_member_cannot_apply_moderation_actions(
    client: AsyncClient, admin_user, db_session
) -> None:
    from app.core.security import create_access_token, hash_password
    from app.models.user import User

    member = User(username="non-admin-moderator", password_hash=hash_password("password123"))
    db_session.add(member)
    await db_session.commit()
    await db_session.refresh(member)
    member_headers = {"Authorization": f"Bearer {create_access_token(member.id)}"}

    response = await client.post(f"/api/users/{admin_user.id}/ban", headers=member_headers)
    assert response.status_code == 403
