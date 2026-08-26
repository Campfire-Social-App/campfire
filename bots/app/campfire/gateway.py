"""The bot's gateway connection — the only reason it shows as online.

The core server's presence is derived from live WebSocket connections
(`ConnectionManager.connect` registers one and broadcasts PRESENCE_UPDATE
`online`), so a bot that only ever made REST calls would sit in the member list
as offline forever. This holds one connection open per bot and answers
heartbeats; it does not act on inbound events — commands arrive over HTTP.
"""

import asyncio
import contextlib
import json
import logging

import websockets

from app.campfire.client import CampfireClient

logger = logging.getLogger(__name__)

_HEARTBEAT_INTERVAL_SECONDS = 30
_MAX_BACKOFF_SECONDS = 60
# The core server not listening yet is the ordinary case on a cold `compose
# up` — it still has migrations to run. Retrying through that is the design, so
# it gets one line; the traceback waits until enough attempts have failed that
# it has stopped looking like boot ordering (~30s of backoff in).
_TRACEBACK_AFTER_FAILURES = 5


class GatewayConnection:
    def __init__(self, *, url: str, client: CampfireClient) -> None:
        self._url = url
        self._client = client
        self._task: asyncio.Task[None] | None = None

    def start(self) -> None:
        if self._task is None:
            self._task = asyncio.create_task(self._run(), name="campfire-gateway")

    async def stop(self) -> None:
        if self._task is None:
            return
        self._task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await self._task
        self._task = None

    async def _run(self) -> None:
        backoff = 1
        failures = 0
        while True:
            try:
                # A fresh token each attempt: the handshake is the only place
                # auth is checked, so a long-lived socket outlives its token,
                # but a reconnect after that point needs a new one.
                token = await self._client.access_token()
                async with websockets.connect(f"{self._url}?token={token}") as socket:
                    logger.info("Gateway connected")
                    backoff = 1
                    failures = 0
                    await self._pump(socket)
            except asyncio.CancelledError:
                raise
            except Exception as exc:
                failures += 1
                logger.warning(
                    "Gateway unavailable (%s: %s), retrying in %ss",
                    type(exc).__name__,
                    exc,
                    backoff,
                    exc_info=failures >= _TRACEBACK_AFTER_FAILURES,
                )
                await asyncio.sleep(backoff)
                backoff = min(backoff * 2, _MAX_BACKOFF_SECONDS)

    async def _pump(self, socket) -> None:
        heartbeat = asyncio.create_task(self._heartbeat(socket))
        try:
            async for _frame in socket:
                # Nothing to do with the events themselves; staying connected is
                # the whole job. Reading keeps the socket drained.
                pass
        finally:
            heartbeat.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await heartbeat

    async def _heartbeat(self, socket) -> None:
        while True:
            await asyncio.sleep(_HEARTBEAT_INTERVAL_SECONDS)
            await socket.send(json.dumps({"op": "HEARTBEAT"}))
