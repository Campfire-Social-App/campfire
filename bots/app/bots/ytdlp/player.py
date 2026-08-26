"""Resolves a track with yt-dlp and pumps its audio into a LiveKit room.

The chain is: yt-dlp gives a direct stream URL, ffmpeg decodes it to raw PCM on
stdout, and this reads that in 10 ms frames and hands each one to LiveKit's
`AudioSource`. `capture_frame` paces itself against the source's internal queue,
so the loop needs no clock of its own — awaiting it *is* the timing.
"""

import asyncio
import contextlib
import logging
from dataclasses import dataclass, field

from livekit import rtc
from yt_dlp import YoutubeDL

logger = logging.getLogger(__name__)

SAMPLE_RATE = 48000
NUM_CHANNELS = 2
# 10 ms per frame: 480 samples per channel, 2 bytes each, 2 channels.
SAMPLES_PER_FRAME = SAMPLE_RATE // 100
BYTES_PER_FRAME = SAMPLES_PER_FRAME * NUM_CHANNELS * 2

_YDL_OPTIONS = {
    "format": "bestaudio/best",
    "noplaylist": True,
    # A bare "/play never gonna give you up" is a search, not a URL.
    "default_search": "ytsearch1",
    "quiet": True,
    "no_warnings": True,
    "skip_download": True,
    "extract_flat": False,
}

# What YouTube answers when it does not believe the caller is a person. It is
# decided per source IP, so it shows up on a VPS while the same build resolves
# fine from a home connection — which makes it impossible to reproduce where it
# does not happen, and worth naming precisely where it does.
_BOT_CHECK = "sign in to confirm"


def ydl_options(*, player_clients: str = "", cookies_file: str = "") -> dict:
    options = dict(_YDL_OPTIONS)
    clients = [c.strip() for c in player_clients.split(",") if c.strip()]
    if clients:
        options["extractor_args"] = {"youtube": {"player_client": clients}}
    if cookies_file:
        options["cookiefile"] = cookies_file
    return options


def _playing_event() -> asyncio.Event:
    """A playback starts unpaused."""
    event = asyncio.Event()
    event.set()
    return event


class TrackUnavailable(RuntimeError):
    """yt-dlp could not turn the query into something playable."""


@dataclass(frozen=True)
class Track:
    title: str
    stream_url: str
    page_url: str
    duration: int | None
    requested_by: str

    def label(self) -> str:
        if self.duration is None:
            return self.title
        minutes, seconds = divmod(self.duration, 60)
        return f"{self.title} ({minutes}:{seconds:02d})"


def _resolve_blocking(query: str, requested_by: str, options: dict) -> Track:
    with YoutubeDL(options) as ydl:
        info = ydl.extract_info(query, download=False)

    if info is None:
        raise TrackUnavailable("nada encontrado")
    # A search comes back as a playlist of one; a direct URL comes back flat.
    entries = info.get("entries")
    if entries:
        info = entries[0]
    if info is None:
        raise TrackUnavailable("nada encontrado")

    stream_url = info.get("url")
    if not stream_url:
        # Some extractors only fill `url` on the chosen format.
        formats = info.get("requested_formats") or []
        stream_url = formats[0].get("url") if formats else None
    if not stream_url:
        raise TrackUnavailable("a faixa não tem áudio que dê para tocar")

    return Track(
        title=info.get("title") or query,
        stream_url=stream_url,
        page_url=info.get("webpage_url") or query,
        duration=int(info["duration"]) if info.get("duration") else None,
        requested_by=requested_by,
    )


async def resolve(
    query: str, requested_by: str, *, player_clients: str = "", cookies_file: str = ""
) -> Track:
    """yt-dlp is synchronous and does network I/O, so it runs off the loop."""
    options = ydl_options(player_clients=player_clients, cookies_file=cookies_file)
    try:
        return await asyncio.to_thread(_resolve_blocking, query, requested_by, options)
    except TrackUnavailable:
        raise
    except Exception as exc:
        message = str(exc).splitlines()[0] if str(exc) else ""
        if _BOT_CHECK in message.lower():
            # The raw yt-dlp text is three lines of flags and a wiki link, which
            # is noise to whoever typed /play. Say what it is and who can fix it.
            raise TrackUnavailable(
                "o YouTube está pedindo login para este servidor (bloqueio por IP). "
                "Quem administra precisa configurar YTDLP_PLAYER_CLIENTS ou "
                "YTDLP_COOKIES_FILE"
            ) from exc
        raise TrackUnavailable(message[:200] or "falhou ao resolver") from exc


@dataclass
class _Playback:
    """One track being decoded and pumped. Lives for as long as it plays."""

    process: asyncio.subprocess.Process
    # Set while playing, cleared by /pause — the pump waits on it before every
    # frame, and ffmpeg blocks on its own pipe once the buffer fills, so there
    # is nothing to drain or discard on resume.
    playing: asyncio.Event = field(default_factory=_playing_event)
    task: asyncio.Task[None] | None = None


class Player:
    """Everything the bot is doing in one voice channel: the room, the queue and
    the track currently being pumped into it."""

    def __init__(
        self,
        *,
        voice_channel_id: str,
        ffmpeg_path: str,
        on_event,
        bitrate: int = 128_000,
    ) -> None:
        self.voice_channel_id = voice_channel_id
        self._ffmpeg_path = ffmpeg_path
        self._bitrate = bitrate
        # Called with a line of feedback to post in the text channel. Async.
        self._on_event = on_event

        self.queue: list[Track] = []
        self.current: Track | None = None

        self._room: rtc.Room | None = None
        self._source: rtc.AudioSource | None = None
        self._playback: _Playback | None = None
        # One command at a time per channel: /skip landing between the end of a
        # track and the start of the next one must not race the queue.
        self._lock = asyncio.Lock()
        self._closed = False

    # ------------------------------------------------------------------ room

    async def connect(self, *, url: str, token: str) -> None:
        if self._room is not None:
            return
        room = rtc.Room()
        # The bot only ever publishes; subscribing to everyone's microphone
        # would be bandwidth spent on audio nothing here listens to.
        await room.connect(url, token, options=rtc.RoomOptions(auto_subscribe=False))
        source = rtc.AudioSource(SAMPLE_RATE, NUM_CHANNELS)
        track = rtc.LocalAudioTrack.create_audio_track("music", source)
        options = rtc.TrackPublishOptions(
            # Published as a microphone so it lands in the same slot every
            # client already renders — including the per-participant volume
            # slider, which is exactly the control you want on a music bot.
            source=rtc.TrackSource.SOURCE_MICROPHONE,
            # DTX cuts transmission during silence, which for music turns quiet
            # passages into dropouts.
            dtx=False,
        )
        # A microphone source otherwise gets LiveKit's speech-tuned default,
        # which is not what you want to push music through. Measuring the
        # received stream showed this does not change the audio *bandwidth*
        # (that is already fullband either way) and does not get a stereo
        # stream out of this SDK version — the track is negotiated mono
        # regardless. What it buys is headroom for the quantisation noise that
        # dense material provokes. Zero leaves LiveKit's default alone.
        # Assigning into the submessage avoids importing AudioEncoding, which
        # this SDK version does not re-export.
        if self._bitrate > 0:
            options.audio_encoding.max_bitrate = self._bitrate
        await room.local_participant.publish_track(track, options)
        self._room = room
        self._source = source
        logger.info("Joined voice channel %s", self.voice_channel_id)

    @property
    def connected(self) -> bool:
        return self._room is not None

    # --------------------------------------------------------------- control

    async def enqueue(self, track: Track) -> int:
        """Adds a track and starts playing if nothing was. Returns its position
        in the queue, 0 meaning it started right away."""
        async with self._lock:
            if self.current is None and not self.queue:
                self.current = track
                await self._start(track)
                return 0
            self.queue.append(track)
            return len(self.queue)

    async def pause(self) -> bool:
        async with self._lock:
            if self._playback is None or not self._playback.playing.is_set():
                return False
            self._playback.playing.clear()
            return True

    async def resume(self) -> bool:
        async with self._lock:
            if self._playback is None or self._playback.playing.is_set():
                return False
            self._playback.playing.set()
            return True

    @property
    def paused(self) -> bool:
        return self._playback is not None and not self._playback.playing.is_set()

    async def skip(self) -> tuple[Track, str | None] | None:
        """Ends the current track early and moves on.

        Returns the track that was skipped plus whatever the move produced (the
        next track, or the goodbye when the queue ran dry) for the caller to
        post — `_advance` never posts while holding the lock.
        """
        async with self._lock:
            skipped = self.current
            if skipped is None:
                return None
            # Cancelling the pump is what stops it from advancing the queue
            # itself, so the move has to happen here.
            await self._stop_playback()
            followup = await self._advance()
        return skipped, followup

    async def stop(self) -> None:
        """Clears everything and leaves the call."""
        async with self._lock:
            self.queue.clear()
            self.current = None
            await self._stop_playback()
            await self._disconnect()

    async def close(self) -> None:
        self._closed = True
        await self.stop()

    # ------------------------------------------------------------- internals

    async def _start(self, track: Track) -> None:
        assert self._source is not None
        # A CDN URL can drop mid-track; without these ffmpeg would just end the
        # stream and the track would stop halfway through. They belong to the
        # HTTP protocol, though, so passing them for any other kind of input
        # makes ffmpeg exit with a bare "Option not found".
        reconnect = (
            ["-reconnect", "1", "-reconnect_streamed", "1", "-reconnect_delay_max", "5"]
            if track.stream_url.startswith(("http://", "https://"))
            else []
        )
        process = await asyncio.create_subprocess_exec(
            self._ffmpeg_path,
            *reconnect,
            "-i", track.stream_url,
            "-vn",
            "-f", "s16le",
            "-ar", str(SAMPLE_RATE),
            "-ac", str(NUM_CHANNELS),
            "-loglevel", "error",
            "pipe:1",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        playback = _Playback(process=process)
        playback.task = asyncio.create_task(
            self._pump(playback, track), name=f"pump-{self.voice_channel_id}"
        )
        self._playback = playback

    async def _pump(self, playback: _Playback, track: Track) -> None:
        assert self._source is not None
        assert playback.process.stdout is not None
        stdout = playback.process.stdout
        failure: str | None = None
        try:
            while True:
                await playback.playing.wait()
                chunk = await stdout.readexactly(BYTES_PER_FRAME)
                await self._source.capture_frame(
                    rtc.AudioFrame(chunk, SAMPLE_RATE, NUM_CHANNELS, SAMPLES_PER_FRAME)
                )
        except asyncio.IncompleteReadError as tail:
            # Normal end of track — the last partial frame is padded out rather
            # than dropped, so a track never ends on a click.
            if tail.partial:
                padded = bytes(tail.partial).ljust(BYTES_PER_FRAME, b"\x00")
                with contextlib.suppress(Exception):
                    await self._source.capture_frame(
                        rtc.AudioFrame(padded, SAMPLE_RATE, NUM_CHANNELS, SAMPLES_PER_FRAME)
                    )
            if playback.process.returncode not in (0, None):
                failure = await _ffmpeg_error(playback.process)
        except asyncio.CancelledError:
            raise
        except Exception:
            logger.exception("Playback of %s failed", track.title)
            failure = "erro ao tocar"
        finally:
            with contextlib.suppress(ProcessLookupError):
                if playback.process.returncode is None:
                    playback.process.kill()

        if failure:
            await self._on_event(f"⚠️ **{track.title}** parou: {failure}")

        # Reached only when the track ran to its end — a skip or a stop cancels
        # this task and advances the queue itself.
        followup: str | None = None
        async with self._lock:
            if self._playback is playback and not self._closed:
                self._playback = None
                followup = await self._advance()
        if followup:
            await self._on_event(followup)

    async def _advance(self) -> str | None:
        """Moves to the next track, or leaves the call when there is none.

        Always called with the lock held, and never posts anything itself: it
        hands the line back so the caller can post it after releasing — a slow
        POST to the core server must not block the next command.
        """
        if self.queue:
            self.current = self.queue.pop(0)
            await self._start(self.current)
            return f"▶️ Tocando **{self.current.label()}**"

        self.current = None
        await self._disconnect()
        return "A fila acabou — saindo do canal de voz."

    async def _stop_playback(self) -> None:
        playback, self._playback = self._playback, None
        if playback is None:
            return
        playback.task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await playback.task
        with contextlib.suppress(ProcessLookupError):
            if playback.process.returncode is None:
                playback.process.kill()
        with contextlib.suppress(Exception):
            await playback.process.wait()

    async def _disconnect(self) -> None:
        room, self._room = self._room, None
        self._source = None
        if room is not None:
            with contextlib.suppress(Exception):
                await room.disconnect()


async def _ffmpeg_error(process: asyncio.subprocess.Process) -> str:
    if process.stderr is None:
        return "erro ao decodificar"
    with contextlib.suppress(Exception):
        raw = await asyncio.wait_for(process.stderr.read(), timeout=2)
        line = raw.decode(errors="replace").strip().splitlines()
        if line:
            return line[-1][:200]
    return "erro ao decodificar"
