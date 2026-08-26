import asyncio
from typing import ClassVar

import pytest
import pytest_asyncio
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.api import commands as commands_api
from app.bots.ytdlp import bot as bot_module
from app.bots.ytdlp.player import Track
from app.core.config import get_settings
from app.core.registry import Registry

SECRET = "test-secret"
HEADERS = {"X-Campfire-Bot-Secret": SECRET}


class FakeCampfireClient:
    """Stands in for the core server: records what the bot posted."""

    def __init__(self) -> None:
        self.messages: list[tuple[str, str]] = []
        self.voice_tokens: list[str] = []

    async def login(self) -> None:
        return None

    async def send_message(self, channel_id: str, content: str) -> dict:
        self.messages.append((channel_id, content))
        return {"id": "message"}

    async def voice_token(self, channel_id: str) -> dict:
        self.voice_tokens.append(channel_id)
        return {"token": "lk-token", "url": "ws://livekit.test:7880", "room": channel_id}


class FakeGateway:
    def __init__(self) -> None:
        self.started = False

    def start(self) -> None:
        self.started = True

    async def stop(self) -> None:
        self.started = False


class FakePlayer:
    """A player with the real one's surface and none of its ffmpeg."""

    instances: ClassVar[list["FakePlayer"]] = []

    def __init__(self, *, voice_channel_id: str, ffmpeg_path: str, on_event) -> None:
        self.voice_channel_id = voice_channel_id
        self._on_event = on_event
        self.queue: list[Track] = []
        self.current: Track | None = None
        self.connected = False
        self.paused = False
        self.stopped = False
        FakePlayer.instances.append(self)

    async def connect(self, *, url: str, token: str) -> None:
        self.connected = True
        self.url = url
        self.token = token

    async def enqueue(self, track: Track) -> int:
        if self.current is None:
            self.current = track
            return 0
        self.queue.append(track)
        return len(self.queue)

    async def pause(self) -> bool:
        if self.current is None or self.paused:
            return False
        self.paused = True
        return True

    async def resume(self) -> bool:
        if not self.paused:
            return False
        self.paused = False
        return True

    async def skip(self):
        if self.current is None:
            return None
        skipped, self.current = self.current, None
        followup = None
        if self.queue:
            self.current = self.queue.pop(0)
            followup = f"▶️ Tocando **{self.current.label()}**"
        return skipped, followup

    async def stop(self) -> None:
        self.stopped = True
        self.connected = False
        self.current = None
        self.queue.clear()

    async def close(self) -> None:
        await self.stop()


def make_track(title: str = "Uma faixa", requested_by: str = "alice") -> Track:
    return Track(
        title=title,
        stream_url="https://cdn.test/audio",
        page_url="https://test/watch",
        duration=125,
        requested_by=requested_by,
    )


@pytest.fixture(autouse=True)
def _settings():
    settings = get_settings()
    previous = settings.bots_shared_secret
    settings.bots_shared_secret = SECRET
    yield settings
    settings.bots_shared_secret = previous


@pytest.fixture
def fake_player(monkeypatch):
    FakePlayer.instances = []
    monkeypatch.setattr(bot_module, "Player", FakePlayer)
    return FakePlayer


@pytest.fixture
def resolved(monkeypatch):
    """Whatever `resolve` should hand back — a Track, or an exception to raise."""
    box: dict = {"track": make_track()}

    async def _resolve(query: str, requested_by: str) -> Track:
        if isinstance(box["track"], Exception):
            raise box["track"]
        return box["track"]

    monkeypatch.setattr(bot_module, "resolve", _resolve)
    return box


@pytest.fixture
def campfire() -> FakeCampfireClient:
    return FakeCampfireClient()


@pytest.fixture
def bot(campfire, fake_player, resolved) -> bot_module.YtDlpBot:
    return bot_module.YtDlpBot(
        client=campfire,
        gateway=FakeGateway(),
        ffmpeg_path="ffmpeg",
    )


@pytest_asyncio.fixture
async def client(bot) -> AsyncClient:
    app = FastAPI()
    registry = Registry()
    registry.register(bot)
    app.state.registry = registry
    app.include_router(commands_api.router)

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://bots.test") as ac:
        yield ac


async def settle() -> None:
    """/play answers before it has resolved anything; let its task finish."""
    for _ in range(5):
        await asyncio.sleep(0)
