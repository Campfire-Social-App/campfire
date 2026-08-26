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


def track(title: str) -> Track:
    return Track(
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
