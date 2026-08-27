"""The queue transitions, with the room and ffmpeg taken out.

`test_commands.py` drives the bot against a fake player; this drives the real
one, so the part that actually decides what plays next is covered by something.
"""

import asyncio

import pytest

from app.bots.ytdlp.player import Player, Track, _Playback

pytestmark = pytest.mark.asyncio


class _DeadProcess:
    """Enough of a process for pause/resume, which only touch the event."""

    returncode = 0


class _TestTrack(Track):
    def _replace_url(self, url: str) -> Track:
        return Track(
            title=self.title, stream_url=url, page_url=self.page_url,
            duration=self.duration, requested_by=self.requested_by,
        )


def track(title: str) -> "_TestTrack":
    return _TestTrack(
        title=title,
        stream_url=f"https://cdn.test/{title}",
        page_url=f"https://test/{title}",
        duration=61,
        requested_by="alice",
    )


@pytest.fixture
def player(monkeypatch):
    """A player wired to nothing: no LiveKit room, no ffmpeg, no pump task.

    `_start` is what spawns both, so replacing it leaves every queue decision —
    which is what these tests are about — running for real.
    """
    said: list[str] = []
    started: list[Track] = []

    async def on_event(text: str) -> None:
        said.append(text)

    player = Player(voice_channel_id="voice", ffmpeg_path="ffmpeg", on_event=on_event)

    async def fake_start(self, track_to_play: Track) -> None:
        started.append(track_to_play)

    async def fake_stop_playback(self) -> None:
        return None

    disconnected: list[bool] = []

    async def fake_disconnect(self) -> None:
        disconnected.append(True)

    monkeypatch.setattr(Player, "_start", fake_start)
    monkeypatch.setattr(Player, "_stop_playback", fake_stop_playback)
    monkeypatch.setattr(Player, "_disconnect", fake_disconnect)

    player.said = said
    player.started = started
    player.disconnected = disconnected
    return player


async def test_the_first_track_starts_and_the_rest_wait(player) -> None:
    assert await player.enqueue(track("um")) == 0
    assert await player.enqueue(track("dois")) == 1
    assert await player.enqueue(track("tres")) == 2

    assert player.current.title == "um"
    assert [t.title for t in player.queue] == ["dois", "tres"]
    # Only the one that is playing was ever handed to ffmpeg.
    assert [t.title for t in player.started] == ["um"]


async def test_skip_advances_and_reports_the_next_one(player) -> None:
    await player.enqueue(track("um"))
    await player.enqueue(track("dois"))

    skipped, followup = await player.skip()

    assert skipped.title == "um"
    assert player.current.title == "dois"
    assert "dois" in followup
    assert player.queue == []


async def test_skip_on_the_last_track_leaves_the_call(player) -> None:
    await player.enqueue(track("um"))

    _skipped, followup = await player.skip()

    assert player.current is None
    assert "fila acabou" in followup
    assert player.disconnected == [True]


async def test_skip_with_nothing_playing(player) -> None:
    assert await player.skip() is None


async def test_pause_and_resume_each_answer_once(player) -> None:
    """The pump waits on this event before every frame, so clearing it is the
    whole of /pause — there is nothing to drain or discard on the way back."""
    await player.enqueue(track("um"))
    player._playback = _Playback(process=_DeadProcess())

    assert await player.pause() is True
    assert player.paused
    # Pausing twice is a refusal the caller sees, not a silent no-op.
    assert await player.pause() is False

    assert await player.resume() is True
    assert not player.paused
    assert await player.resume() is False


async def test_pause_with_nothing_playing(player) -> None:
    assert await player.pause() is False
    assert await player.resume() is False


async def test_stop_clears_everything_and_leaves(player) -> None:
    await player.enqueue(track("um"))
    await player.enqueue(track("dois"))

    await player.stop()

    assert player.current is None
    assert player.queue == []
    assert player.disconnected == [True]


async def test_advancing_hands_its_line_back_instead_of_posting_it(player) -> None:
    """A slow POST to the core server must not be made while the lock the next
    command needs is held, so `_advance` returns the line for the caller."""
    await player.enqueue(track("um"))
    await player.enqueue(track("dois"))

    _skipped, followup = await player.skip()

    assert followup is not None
    assert player.said == []


async def test_two_commands_at_once_do_not_interleave(player) -> None:
    """Two people hitting /skip together must not both advance the queue."""
    await player.enqueue(track("um"))
    await player.enqueue(track("dois"))
    await player.enqueue(track("tres"))

    first, second = await asyncio.gather(player.skip(), player.skip())

    assert {first[0].title, second[0].title} == {"um", "dois"}
    assert player.current.title == "tres"


async def test_reconnect_options_only_go_to_http_inputs(monkeypatch) -> None:
    """ffmpeg's -reconnect belongs to the HTTP protocol. Passing it for any
    other input makes it exit with a bare "Option not found", which tells
    whoever reads the log nothing at all."""
    calls: list[list[str]] = []

    class _Process:
        returncode = None
        stdout = None
        stderr = None

        def kill(self) -> None:
            return None

    async def fake_exec(*args, **kwargs):
        calls.append(list(args))
        return _Process()

    monkeypatch.setattr(asyncio, "create_subprocess_exec", fake_exec)
    monkeypatch.setattr(asyncio, "create_task", lambda coro, **kw: coro.close())

    player = Player(voice_channel_id="voice", ffmpeg_path="ffmpeg", on_event=_noop)
    player._source = object()

    await player._start(track("remoto")._replace_url("https://cdn.test/audio"))
    assert "-reconnect" in calls[-1]

    await player._start(track("local")._replace_url("/tmp/faixa.wav"))
    assert "-reconnect" not in calls[-1]
    # The input itself still gets through either way.
    assert calls[-1][calls[-1].index("-i") + 1] == "/tmp/faixa.wav"


async def _noop(_text: str) -> None:
    return None


async def test_player_clients_and_cookies_reach_yt_dlp() -> None:
    """These exist for one reason: YouTube's "confirm you're not a bot" check is
    decided per source IP, so a VPS trips it while the same build resolves fine
    from a home connection. The knobs have to actually arrive."""
    from app.bots.ytdlp.player import ydl_options

    plain = ydl_options()
    assert "extractor_args" not in plain, "empty means yt-dlp's own default order"
    assert "cookiefile" not in plain

    tuned = ydl_options(
        player_clients="tv, web_embedded ",
        cookies_file="/run/cookies.txt",
        pot_base_url="http://bgutil:4416",
    )
    assert tuned["extractor_args"]["youtube"] == {"player_client": ["tv", "web_embedded"]}
    assert tuned["cookiefile"] == "/run/cookies.txt"
    # The key is derived from the plugin's provider class (BgUtilHTTPPTP ->
    # PROVIDER_KEY BgUtilHTTP). Getting it wrong fails *silently* — yt-dlp just
    # never consults the provider — so it is pinned here.
    assert tuned["extractor_args"]["youtubepot-bgutilhttp"] == {
        "base_url": ["http://bgutil:4416"]
    }
    # The rest of the options are untouched.
    assert tuned["format"] == plain["format"]
    assert tuned["default_search"] == "ytsearch1"


async def test_the_bot_check_is_reported_in_words_a_person_can_act_on(monkeypatch) -> None:
    """yt-dlp's own text is three lines of flags and a wiki link — noise to
    whoever typed /play, and it hides who can actually fix it."""
    from app.bots.ytdlp import player as player_module

    def _blocked(*args, **kwargs):
        raise RuntimeError(
            "ERROR: [youtube] abc: Sign in to confirm you're not a bot. "
            "Use --cookies-from-browser or --cookies for the authentication."
        )

    monkeypatch.setattr(player_module, "_resolve_blocking", _blocked)

    with pytest.raises(player_module.TrackUnavailable) as raised:
        await player_module.resolve("uma faixa", "alice")

    message = str(raised.value)
    assert "bloqueio por IP" in message
    assert "YTDLP_PLAYER_CLIENTS" in message
    # No raw flags leaking into the channel.
    assert "--cookies-from-browser" not in message


async def test_other_failures_keep_their_own_message(monkeypatch) -> None:
    from app.bots.ytdlp import player as player_module

    def _gone(*args, **kwargs):
        raise RuntimeError("ERROR: [youtube] xyz: Video unavailable")

    monkeypatch.setattr(player_module, "_resolve_blocking", _gone)

    with pytest.raises(player_module.TrackUnavailable) as raised:
        await player_module.resolve("uma faixa", "alice")
    assert "Video unavailable" in str(raised.value)


async def test_the_pot_key_matches_what_the_installed_plugin_registers() -> None:
    """A typo here would cost nothing at import time and everything at runtime:
    yt-dlp looks the provider's settings up by this exact name, and an unknown
    key is ignored rather than reported."""
    from yt_dlp import YoutubeDL
    from yt_dlp.extractor.youtube.pot._registry import _pot_providers

    from app.bots.ytdlp.player import ydl_options

    # The registry fills in when yt-dlp loads its plugins, which construction
    # triggers — reading it cold gives an empty dict.
    YoutubeDL({"quiet": True, "no_warnings": True}).close()

    key = next(iter(ydl_options(pot_base_url="http://x:4416")["extractor_args"]))
    registered = {
        f"youtubepot-{cls.PROVIDER_KEY.lower()}"
        for cls in _pot_providers.value.values()
        if hasattr(cls, "PROVIDER_KEY")
    }
    assert registered, "o plugin de PO token não está instalado"
    assert key in registered, f"{key} não está entre {sorted(registered)}"
