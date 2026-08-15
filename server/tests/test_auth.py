import pytest
from httpx import AsyncClient

pytestmark = pytest.mark.asyncio


async def test_register_with_invalid_invite_fails(client: AsyncClient) -> None:
    resp = await client.post(
        "/api/auth/register",
        json={"invite_code": "does-not-exist", "username": "bob", "password": "password123"},
    )
    assert resp.status_code == 404


async def test_register_login_refresh_flow(client: AsyncClient, admin_headers: dict[str, str]) -> None:
    invite_resp = await client.post("/api/invites", json={"max_uses": 1}, headers=admin_headers)
    assert invite_resp.status_code == 201
    code = invite_resp.json()["code"]

    register_resp = await client.post(
        "/api/auth/register",
        json={"invite_code": code, "username": "friend1", "password": "friendpass1"},
    )
    assert register_resp.status_code == 201
    body = register_resp.json()
    assert body["user"]["username"] == "friend1"
    assert body["user"]["is_admin"] is False
    assert "access_token" in body and "refresh_token" in body

    login_resp = await client.post(
        "/api/auth/login", json={"username": "friend1", "password": "friendpass1"}
    )
    assert login_resp.status_code == 200
    refresh_token = login_resp.json()["refresh_token"]

    refresh_resp = await client.post("/api/auth/refresh", json={"refresh_token": refresh_token})
    assert refresh_resp.status_code == 200
    assert "access_token" in refresh_resp.json()


async def test_register_reuses_exhausted_invite_fails(
    client: AsyncClient, admin_headers: dict[str, str]
) -> None:
    invite_resp = await client.post("/api/invites", json={"max_uses": 1}, headers=admin_headers)
    code = invite_resp.json()["code"]

    first = await client.post(
        "/api/auth/register",
        json={"invite_code": code, "username": "friend1", "password": "friendpass1"},
    )
    assert first.status_code == 201

    second = await client.post(
        "/api/auth/register",
        json={"invite_code": code, "username": "friend2", "password": "friendpass2"},
    )
    assert second.status_code == 410


async def test_login_wrong_password_fails(client: AsyncClient, admin_headers: dict[str, str]) -> None:
    resp = await client.post("/api/auth/login", json={"username": "admin", "password": "wrong"})
    assert resp.status_code == 401


async def test_unauthenticated_request_is_rejected(client: AsyncClient) -> None:
    resp = await client.get("/api/channels")
    assert resp.status_code == 401


async def test_non_admin_cannot_create_invite(client: AsyncClient, admin_headers: dict[str, str]) -> None:
    invite_resp = await client.post("/api/invites", json={"max_uses": 1}, headers=admin_headers)
    code = invite_resp.json()["code"]
    register_resp = await client.post(
        "/api/auth/register",
        json={"invite_code": code, "username": "friend1", "password": "friendpass1"},
    )
    friend_token = register_resp.json()["access_token"]

    resp = await client.post(
        "/api/invites",
        json={"max_uses": 1},
        headers={"Authorization": f"Bearer {friend_token}"},
    )
    assert resp.status_code == 403
