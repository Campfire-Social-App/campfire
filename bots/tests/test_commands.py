import pytest
from httpx import AsyncClient

from app.bots.ytdlp.bot import _format_queue
from app.bots.ytdlp.player import TrackUnavailable
from tests.conftest import HEADERS, make_track, settle

pytestmark = pytest.mark.asyncio

TEXT_CHANNEL = "11111111-1111-1111-1111-111111111111"
VOICE_CHANNEL = "22222222-2222-2222-2222-222222222222"


def _body(args: str = "", *, voice: str | None = VOICE_CHANNEL) -> dict:
    return {
        "user": {"id": "33333333-3333-3333-3333-333333333333", "username": "alice"},
        "text_channel_id": TEXT_CHANNEL,
        "voice_channel_id": voice,
        "args": args,
    }


async def test_commands_require_the_shared_secret(client: AsyncClient) -> None:
    assert (await client.get("/commands")).status_code == 401
    assert (
        await client.get("/commands", headers={"X-Campfire-Bot-Secret": "wrong"})
    ).status_code == 401


async def test_command_list_describes_every_command(client: AsyncClient) -> None:
    resp = await client.get("/commands", headers=HEADERS)
    assert resp.status_code == 200
    by_name = {c["name"]: c for c in resp.json()}
    assert set(by_name) == {"play", "pause", "resume", "skip", "stop", "queue"}
    assert by_name["play"]["usage"] == "<url ou busca>"
    assert by_name["play"]["requires_voice"] is True
    # The only one that reads without touching the audio.
    assert by_name["queue"]["requires_voice"] is False


async def test_unknown_command_is_404(client: AsyncClient) -> None:
    resp = await client.post("/commands/dance", json=_body("x"), headers=HEADERS)
    assert resp.status_code == 404


async def test_play_needs_a_voice_channel(client: AsyncClient) -> None:
    resp = await client.post("/commands/play", json=_body("x", voice=None), headers=HEADERS)
    assert resp.status_code == 400
    assert "voz" in resp.json()["detail"]


async def test_play_needs_something_to_play(client: AsyncClient) -> None:
    resp = await client.post("/commands/play", json=_body("   "), headers=HEADERS)
    assert resp.status_code == 400


async def test_play_joins_the_call_and_reports_in_the_channel(
    client: AsyncClient, campfire, fake_player, resolved
) -> None:
    resolved["track"] = make_track("Uma faixa")

    resp = await client.post("/commands/play", json=_body("uma faixa"), headers=HEADERS)
    assert resp.status_code == 202
    await settle()

    player = fake_player.instances[0]
    assert player.voice_channel_id == VOICE_CHANNEL
    assert player.connected
    # The room credentials came from the core server, keyed by the voice channel
    # the *server* said the caller was in.
    assert campfire.voice_tokens == [VOICE_CHANNEL]
    assert player.url == "ws://livekit.test:7880"

    channel_id, text = campfire.messages[-1]
    assert channel_id == TEXT_CHANNEL
    assert "Tocando" in text and "Uma faixa" in text


async def test_livekit_url_override_wins(client: AsyncClient, bot, campfire, fake_player) -> None:
    """Set when the public SFU address is not routable from this container."""
    bot._livekit_url_override = "ws://livekit:7880"

    await client.post("/commands/play", json=_body("uma faixa"), headers=HEADERS)
    await settle()

    assert fake_player.instances[0].url == "ws://livekit:7880"


async def test_play_queues_behind_what_is_already_playing(
    client: AsyncClient, campfire, fake_player, resolved
) -> None:
    resolved["track"] = make_track("Primeira")
    await client.post("/commands/play", json=_body("primeira"), headers=HEADERS)
    await settle()

    resolved["track"] = make_track("Segunda")
    await client.post("/commands/play", json=_body("segunda"), headers=HEADERS)
    await settle()

    # One player for the call, not one per command.
    assert len(fake_player.instances) == 1
    assert fake_player.instances[0].current.title == "Primeira"
    assert [t.title for t in fake_player.instances[0].queue] == ["Segunda"]
    assert "fila" in campfire.messages[-1][1]


async def test_a_track_that_cannot_be_resolved_is_reported_and_the_bot_leaves(
    client: AsyncClient, campfire, fake_player, resolved
) -> None:
    resolved["track"] = TrackUnavailable("vídeo indisponível")

    resp = await client.post("/commands/play", json=_body("nada"), headers=HEADERS)
    assert resp.status_code == 202
    await settle()

    assert "indisponível" in campfire.messages[-1][1]
    # Nothing to play means nothing to sit in the call for.
    assert fake_player.instances[0].stopped


async def test_pause_and_resume(client: AsyncClient, campfire, fake_player) -> None:
    await client.post("/commands/play", json=_body("uma faixa"), headers=HEADERS)
    await settle()

    assert (await client.post("/commands/pause", json=_body(), headers=HEADERS)).status_code == 202
    assert fake_player.instances[0].paused
    # Pausing twice is a refusal the caller sees, not a silent no-op.
    assert (await client.post("/commands/pause", json=_body(), headers=HEADERS)).status_code == 400

    assert (await client.post("/commands/resume", json=_body(), headers=HEADERS)).status_code == 202
    assert not fake_player.instances[0].paused
    assert (await client.post("/commands/resume", json=_body(), headers=HEADERS)).status_code == 400


async def test_pause_with_nothing_playing(client: AsyncClient) -> None:
    resp = await client.post("/commands/pause", json=_body(), headers=HEADERS)
    assert resp.status_code == 400
    assert "nada tocando" in resp.json()["detail"]


async def test_skip_moves_to_the_next_track(
    client: AsyncClient, campfire, fake_player, resolved
) -> None:
    resolved["track"] = make_track("Primeira")
    await client.post("/commands/play", json=_body("primeira"), headers=HEADERS)
    await settle()
    resolved["track"] = make_track("Segunda")
    await client.post("/commands/play", json=_body("segunda"), headers=HEADERS)
    await settle()

    resp = await client.post("/commands/skip", json=_body(), headers=HEADERS)
    assert resp.status_code == 202
    assert fake_player.instances[0].current.title == "Segunda"

    posted = [text for _channel, text in campfire.messages]
    assert any("Pulei" in text and "Primeira" in text for text in posted)
    assert any("Tocando" in text and "Segunda" in text for text in posted)


async def test_stop_leaves_the_call(client: AsyncClient, campfire, fake_player) -> None:
    await client.post("/commands/play", json=_body("uma faixa"), headers=HEADERS)
    await settle()

    resp = await client.post("/commands/stop", json=_body(), headers=HEADERS)
    assert resp.status_code == 202
    assert fake_player.instances[0].stopped

    # The call is forgotten, so a follow-up command has nothing to act on.
    assert (await client.post("/commands/pause", json=_body(), headers=HEADERS)).status_code == 400


async def test_queue_is_empty_before_anything_plays(client: AsyncClient) -> None:
    resp = await client.post("/commands/queue", json=_body(), headers=HEADERS)
    assert resp.status_code == 400
    assert "vazia" in resp.json()["detail"]


async def test_queue_lists_what_is_playing_and_what_is_next(
    client: AsyncClient, campfire, resolved
) -> None:
    resolved["track"] = make_track("Primeira")
    await client.post("/commands/play", json=_body("primeira"), headers=HEADERS)
    await settle()
    resolved["track"] = make_track("Segunda")
    await client.post("/commands/play", json=_body("segunda"), headers=HEADERS)
    await settle()

    resp = await client.post("/commands/queue", json=_body(), headers=HEADERS)
    assert resp.status_code == 202
    listing = campfire.messages[-1][1]
    assert "Primeira" in listing
    assert "1. Segunda" in listing


async def test_feedback_follows_the_channel_the_command_came_from(
    client: AsyncClient, campfire
) -> None:
    await client.post("/commands/play", json=_body("uma faixa"), headers=HEADERS)
    await settle()

    elsewhere = "44444444-4444-4444-4444-444444444444"
    body = _body()
    body["text_channel_id"] = elsewhere
    await client.post("/commands/pause", json=body, headers=HEADERS)

    assert campfire.messages[-1][0] == elsewhere


async def test_queue_listing_marks_a_paused_track() -> None:
    current = make_track("Tocando agora")
    listing = _format_queue(current, [make_track("Depois")], paused=True)
    assert listing.startswith("⏸️")
    assert "2:05" in listing
    assert "1. Depois" in listing


async def test_an_unconfigured_service_hosts_no_bots(monkeypatch, caplog) -> None:
    """No credentials must mean a running, inert service — not a failed deploy.

    The clients read an empty command list as "this deployment has no bots" and
    never open the `/` menu, so the chat and the voice are unaffected.
    """
    from app.core.config import get_settings
    from app.main import build_registry

    settings = get_settings()
    monkeypatch.setattr(settings, "bot_password", "")
    monkeypatch.setattr(settings, "bots_shared_secret", "")

    registry, clients = build_registry()

    assert registry.specs() == []
    assert registry.bots == []
    # No client either: nothing to sign in with, so nothing tries.
    assert clients == []
    assert "BOT_PASSWORD and BOTS_SHARED_SECRET" in caplog.text


async def test_a_configured_service_hosts_the_ytdlp_bot(monkeypatch) -> None:
    from app.core.config import get_settings
    from app.main import build_registry

    settings = get_settings()
    monkeypatch.setattr(settings, "bot_password", "senha")
    monkeypatch.setattr(settings, "bots_shared_secret", "segredo")

    registry, clients = build_registry()
    try:
        assert [bot.name for bot in registry.bots] == ["ytdlp"]
        assert {spec.name for spec in registry.specs()} == {
            "play",
            "pause",
            "resume",
            "skip",
            "stop",
            "queue",
        }
    finally:
        for client in clients:
            await client.aclose()
