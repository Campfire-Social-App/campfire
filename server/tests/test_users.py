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
