"""REST client for the core server, from the bot's side of the wire.

Mirrors what `client/src/api/client.ts` and `app/lib/api/token_holder.dart`
already do for the human clients: sign in once, keep the token pair, and on a
401 refresh exactly once — single-flight — before retrying the request.
"""

import asyncio
import logging
from typing import Any

import httpx

logger = logging.getLogger(__name__)

_TIMEOUT = httpx.Timeout(30.0, connect=5.0)


class CampfireError(RuntimeError):
    def __init__(self, status_code: int, detail: str) -> None:
        super().__init__(f"{status_code}: {detail}")
        self.status_code = status_code
        self.detail = detail


class CampfireClient:
    def __init__(self, *, base_url: str, username: str, password: str) -> None:
        self._base_url = base_url.rstrip("/")
        self._username = username
        self._password = password
        self._http = httpx.AsyncClient(base_url=self._base_url, timeout=_TIMEOUT)
        self._access_token: str | None = None
        self._refresh_token: str | None = None
        self._user: dict[str, Any] | None = None
        # Serialises login and refresh: several commands can land at once, and
        # a burst of 401s must not turn into a burst of refreshes.
        self._auth_lock = asyncio.Lock()

    @property
    def user(self) -> dict[str, Any] | None:
        return self._user

    @property
    def user_id(self) -> str | None:
        return self._user["id"] if self._user else None

    async def aclose(self) -> None:
        await self._http.aclose()

    # ------------------------------------------------------------------ auth

    async def login(self) -> dict[str, Any]:
        async with self._auth_lock:
            response = await self._http.post(
                "/api/auth/login",
                json={"username": self._username, "password": self._password},
            )
            if response.status_code != 200:
                raise CampfireError(response.status_code, _detail(response))
            body = response.json()
            self._access_token = body["access_token"]
            self._refresh_token = body["refresh_token"]
            self._user = body["user"]
            logger.info("Signed in as %s", self._username)
            return body

    async def access_token(self) -> str:
        """A token good enough to open the gateway with, signing in if needed."""
        if self._access_token is None:
            await self.login()
        assert self._access_token is not None
        return self._access_token

    async def _refresh(self, stale_token: str | None) -> None:
        async with self._auth_lock:
            # Someone else already refreshed while we waited for the lock.
            if self._access_token != stale_token:
                return
            if self._refresh_token is None:
                self._access_token = None
                return
            response = await self._http.post(
                "/api/auth/refresh", json={"refresh_token": self._refresh_token}
            )
            if response.status_code == 200:
                self._access_token = response.json()["access_token"]
                return
            # The refresh token is gone too (server restart with a new secret,
            # revoked session): fall back to a full sign-in.
            self._access_token = None
            self._refresh_token = None

        await self.login()

    async def request(
        self, method: str, path: str, *, json: Any | None = None
    ) -> Any:
        token = await self.access_token()
        response = await self._http.request(
            method, path, json=json, headers={"Authorization": f"Bearer {token}"}
        )
        if response.status_code == 401:
            await self._refresh(token)
            token = await self.access_token()
            response = await self._http.request(
                method, path, json=json, headers={"Authorization": f"Bearer {token}"}
            )
        if response.status_code >= 400:
            raise CampfireError(response.status_code, _detail(response))
        if response.status_code == 204 or not response.content:
            return None
        return response.json()

    # --------------------------------------------------------------- actions

    async def send_message(self, channel_id: str, content: str) -> dict[str, Any]:
        """Posts as the bot. This is how every asynchronous result reaches the
        person who ran the command."""
        return await self.request(
            "POST",
            f"/api/channels/{channel_id}/messages",
            json={"content": content, "attachment_ids": [], "reply_to_id": None},
        )

    async def voice_token(self, channel_id: str) -> dict[str, Any]:
        """Room credentials for a voice channel.

        Deliberately the same endpoint the clients use rather than minting a
        token here: the identity it embeds is the bot's user id, which is what
        makes the LiveKit `participant_joined` webhook place the bot in the
        voice roster everyone already renders.
        """
        return await self.request("POST", f"/api/voice/{channel_id}/token", json={"muted": False})


def _detail(response: httpx.Response) -> str:
    try:
        body = response.json()
    except ValueError:
        return response.text[:200]
    if isinstance(body, dict) and "detail" in body:
        return str(body["detail"])
    return str(body)[:200]
