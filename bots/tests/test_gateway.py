"""How a core server that is not up yet reads in the logs.

Retrying through it is the design — the bots container and the server container
start together, and the server still has migrations to run before it listens.
What matters is that the wait does not look like a crash.
"""

import asyncio

import pytest

from app.campfire import gateway as gateway_module
from app.campfire.gateway import GatewayConnection

pytestmark = pytest.mark.asyncio


class _Unreachable:
    """A client that can never get a token, as during the server's migrations."""

    def __init__(self) -> None:
        self.attempts = 0

    async def access_token(self) -> str:
        self.attempts += 1
        raise ConnectionError("All connection attempts failed")


@pytest.fixture
def instant_backoff(monkeypatch):
    """Runs the retry loop without waiting out its real backoff.

    Patches the module's `asyncio.sleep`, so it is in force only for the test
    that asks for it.
    """
    def _stop_after(attempts: int, client: _Unreachable):
        async def _sleep(_seconds: float) -> None:
            if client.attempts >= attempts:
                raise asyncio.CancelledError

        monkeypatch.setattr(gateway_module.asyncio, "sleep", _sleep)

    return _stop_after


async def test_the_first_retries_are_one_line_each(caplog, instant_backoff) -> None:
    client = _Unreachable()
    instant_backoff(3, client)
    connection = GatewayConnection(url="ws://server:8000/gateway", client=client)

    with caplog.at_level("WARNING"):
        connection.start()
        with pytest.raises(asyncio.CancelledError):
            await connection._task

    warnings = [r for r in caplog.records if r.levelname == "WARNING"]
    assert warnings, "the wait has to be visible at all"
    # Says what is wrong and that it is retrying, without a wall of traceback
    # that reads as a failure on every cold boot.
    assert "Gateway unavailable" in warnings[0].message
    assert "ConnectionError" in warnings[0].getMessage()
    assert not any(record.exc_info for record in warnings)


async def test_a_wait_that_stops_looking_like_boot_gets_the_traceback(
    caplog, instant_backoff
) -> None:
    client = _Unreachable()
    instant_backoff(gateway_module._TRACEBACK_AFTER_FAILURES + 1, client)
    connection = GatewayConnection(url="ws://server:8000/gateway", client=client)

    with caplog.at_level("WARNING"):
        connection.start()
        with pytest.raises(asyncio.CancelledError):
            await connection._task

    warnings = [r for r in caplog.records if r.levelname == "WARNING"]
    assert not warnings[0].exc_info
    # By here the backoff has been growing for ~30s: this is no longer the
    # server finishing its migrations, and the detail earns its place.
    assert warnings[-1].exc_info


async def test_stop_is_quiet(caplog) -> None:
    """Shutting down must not look like a connection failure."""
    client = _Unreachable()
    connection = GatewayConnection(url="ws://server:8000/gateway", client=client)
    connection.start()
    await connection.stop()

    assert [r for r in caplog.records if r.levelname == "WARNING"] == []
