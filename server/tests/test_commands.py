import uuid
from datetime import UTC, datetime, timedelta

import httpx
import pytest
from httpx import AsyncClient

import app.api.commands as commands_module
from app.core.config import get_settings

pytestmark = pytest.mark.asyncio


@pytest.fixture(autouse=True)
def _no_ambient_bots_service():
    """Start every test from "this deployment has no bots".

    `get_settings` reads the developer's own `server/.env`, so a machine that
    points BOTS_URL at a running bots service would otherwise have these tests
    talk to it for real — passing on CI and failing locally. The module-level
    command cache is cleared for the same reason.
    """
    settings = get_settings()
    previous = (settings.bots_url, settings.bots_shared_secret)
    settings.bots_url = None
    settings.bots_shared_secret = ""
    commands_module._cache = None
    yield
    settings.bots_url, settings.bots_shared_secret = previous
    commands_module._cache = None


@pytest.fixture
def bots_configured():
    """Point the server at a bots service for the duration of one test."""
    settings = get_settings()
    settings.bots_url = "http://bots.test:8100"
    settings.bots_shared_secret = "shared-secret"
    commands_module._cache = None


@pytest.fixture
def fake_bots(monkeypatch):
    """Stands in for the bots service, recording what the server forwarded."""
    calls: list[dict] = []
    responses: dict[str, httpx.Response] = {}

    class _Client:
        def __init__(self, *args, **kwargs) -> None:
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, *args) -> None:
            return None

        async def get(self, url, headers=None):
            calls.append({"method": "GET", "url": url, "headers": headers})
            return _answer("GET", url, httpx.Response(200, json=[]))

        async def post(self, url, json=None, headers=None):
            calls.append({"method": "POST", "url": url, "json": json, "headers": headers})
            return _answer("POST", url, httpx.Response(202, json={"ok": True}))

    def _answer(method: str, url: str, fallback: httpx.Response) -> httpx.Response:
        # `raise_for_status` needs the originating request, which a hand-built
        # Response does not carry.
        response = responses.get(method, fallback)
        response.request = httpx.Request(method, url)
        return response

    monkeypatch.setattr(commands_module.httpx, "AsyncClient", _Client)
    return {"calls": calls, "responses": responses}


async def test_command_list_is_empty_without_a_bots_service(
    client: AsyncClient, admin_headers: dict[str, str]
) -> None:
    resp = await client.get("/api/commands", headers=admin_headers)
    assert resp.status_code == 200
    assert resp.json() == []


async def test_command_list_comes_from_the_bots_service(
    client: AsyncClient, admin_headers: dict[str, str], bots_configured, fake_bots
) -> None:
    fake_bots["responses"]["GET"] = httpx.Response(
        200,
        json=[
            {
                "name": "play",
                "description": "Toca uma faixa",
                "usage": "<url ou busca>",
                "requires_voice": True,
            }
        ],
    )

    resp = await client.get("/api/commands", headers=admin_headers)
    assert resp.status_code == 200
    assert [c["name"] for c in resp.json()] == ["play"]
    assert fake_bots["calls"][0]["url"] == "http://bots.test:8100/commands"
    assert fake_bots["calls"][0]["headers"]["X-Campfire-Bot-Secret"] == "shared-secret"


async def test_command_list_survives_a_dead_bots_service(
    client: AsyncClient, admin_headers: dict[str, str], bots_configured, monkeypatch
) -> None:
    class _Dead:
        def __init__(self, *args, **kwargs) -> None:
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, *args) -> None:
            return None

        async def get(self, *args, **kwargs):
            raise httpx.ConnectError("no route")

    monkeypatch.setattr(commands_module.httpx, "AsyncClient", _Dead)

    resp = await client.get("/api/commands", headers=admin_headers)
    assert resp.status_code == 200
    assert resp.json() == []


async def test_command_list_is_empty_when_the_bots_service_hosts_none(
    client: AsyncClient, admin_headers: dict[str, str], bots_configured, fake_bots
) -> None:
    """The state a VPS is in between deploying bots/ and writing its secrets:
    the service is up but unconfigured, so it turns the request away. That has
    to read as "no commands", not as a broken command list."""
    fake_bots["responses"]["GET"] = httpx.Response(401, json={"detail": "Not authorised"})

    resp = await client.get("/api/commands", headers=admin_headers)
    assert resp.status_code == 200
    assert resp.json() == []


async def _text_channel(client: AsyncClient, headers: dict[str, str], name: str) -> str:
    resp = await client.post("/api/channels", json={"name": name, "type": "text"}, headers=headers)
    return resp.json()["id"]


async def test_run_command_forwards_the_callers_voice_channel(
    client: AsyncClient, admin_headers: dict[str, str], admin_user, bots_configured, fake_bots
) -> None:
    """The bot is told which call the caller is in by this process, not by the
    request body — that is what stops someone dragging the bot into a call they
    are not part of themselves."""
    from app.gateway.manager import VoiceParticipantState, manager

    channel_id = await _text_channel(client, admin_headers, "geral-commands")
    voice_channel_id = uuid.uuid4()
    manager.voice_state[admin_user.id] = VoiceParticipantState(
        user_id=admin_user.id, channel_id=voice_channel_id, username=admin_user.username
    )
    try:
        resp = await client.post(
            "/api/commands",
            json={"channel_id": channel_id, "name": "play", "args": "never gonna give you up"},
            headers=admin_headers,
        )
    finally:
        manager.voice_state.pop(admin_user.id, None)

    assert resp.status_code == 202
    forwarded = fake_bots["calls"][0]
    assert forwarded["url"] == "http://bots.test:8100/commands/play"
    assert forwarded["json"]["voice_channel_id"] == str(voice_channel_id)
    assert forwarded["json"]["text_channel_id"] == channel_id
    assert forwarded["json"]["user"]["id"] == str(admin_user.id)
    assert forwarded["json"]["args"] == "never gonna give you up"


async def test_run_command_reports_no_voice_channel_as_null(
    client: AsyncClient, admin_headers: dict[str, str], bots_configured, fake_bots
) -> None:
    channel_id = await _text_channel(client, admin_headers, "geral-no-voice")
    resp = await client.post(
        "/api/commands",
        json={"channel_id": channel_id, "name": "queue", "args": ""},
        headers=admin_headers,
    )
    assert resp.status_code == 202
    assert fake_bots["calls"][0]["json"]["voice_channel_id"] is None


async def test_run_command_passes_the_bots_refusal_through(
    client: AsyncClient, admin_headers: dict[str, str], bots_configured, fake_bots
) -> None:
    fake_bots["responses"]["POST"] = httpx.Response(
        400, json={"detail": "Entre num canal de voz primeiro"}
    )
    channel_id = await _text_channel(client, admin_headers, "geral-refusal")

    resp = await client.post(
        "/api/commands",
        json={"channel_id": channel_id, "name": "play", "args": "x"},
        headers=admin_headers,
    )
    assert resp.status_code == 400
    assert resp.json()["detail"] == "Entre num canal de voz primeiro"


async def test_run_command_answers_503_without_a_bots_service(
    client: AsyncClient, admin_headers: dict[str, str]
) -> None:
    channel_id = await _text_channel(client, admin_headers, "geral-503")
    resp = await client.post(
        "/api/commands",
        json={"channel_id": channel_id, "name": "play", "args": "x"},
        headers=admin_headers,
    )
    assert resp.status_code == 503


async def test_run_command_rejects_a_timed_out_user(
    client: AsyncClient, admin_headers: dict[str, str], admin_user, db_session, bots_configured
) -> None:
    channel_id = await _text_channel(client, admin_headers, "geral-timeout")
    admin_user.timed_out_until = datetime.now(UTC) + timedelta(hours=1)
    db_session.add(admin_user)
    await db_session.commit()

    resp = await client.post(
        "/api/commands",
        json={"channel_id": channel_id, "name": "play", "args": "x"},
        headers=admin_headers,
    )
    assert resp.status_code == 403


async def test_run_command_hides_a_dm_the_caller_is_not_in(
    client: AsyncClient, db_session, bots_configured
) -> None:
    from app.core.security import create_access_token, hash_password
    from app.models.user import User

    members = []
    for username in ("cmd-alice", "cmd-bob", "cmd-carol"):
        user = User(username=username, password_hash=hash_password("password123"))
        db_session.add(user)
        members.append(user)
    await db_session.commit()
    for user in members:
        await db_session.refresh(user)
    alice, bob, carol = members

    dm = await client.post(
        "/api/dms",
        json={"user_id": str(bob.id)},
        headers={"Authorization": f"Bearer {create_access_token(alice.id)}"},
    )
    dm_id = dm.json()["id"]

    resp = await client.post(
        "/api/commands",
        json={"channel_id": dm_id, "name": "play", "args": "x"},
        headers={"Authorization": f"Bearer {create_access_token(carol.id)}"},
    )
    assert resp.status_code == 404
