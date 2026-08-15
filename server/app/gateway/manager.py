import uuid
from dataclasses import dataclass

from fastapi import WebSocket

from app.gateway.events import GatewayEvent


@dataclass
class VoiceParticipantState:
    user_id: uuid.UUID
    channel_id: uuid.UUID
    username: str
    muted: bool = False
    speaking: bool = False


class ConnectionManager:
    """In-memory registry of live gateway connections and ephemeral voice state.

    A single-process deployment is assumed (per PLANO.md scope) — no need for a
    shared external registry (e.g. Redis pub/sub) across multiple server instances.
    """

    def __init__(self) -> None:
        self._connections: dict[uuid.UUID, set[WebSocket]] = {}
        self.voice_state: dict[uuid.UUID, VoiceParticipantState] = {}

    async def connect(self, user_id: uuid.UUID, websocket: WebSocket) -> None:
        await websocket.accept()
        self._connections.setdefault(user_id, set()).add(websocket)

    def disconnect(self, user_id: uuid.UUID, websocket: WebSocket) -> None:
        sockets = self._connections.get(user_id)
        if not sockets:
            return
        sockets.discard(websocket)
        if not sockets:
            self._connections.pop(user_id, None)

    def is_connected(self, user_id: uuid.UUID) -> bool:
        return user_id in self._connections

    def online_user_ids(self) -> list[uuid.UUID]:
        return list(self._connections.keys())

    async def send_to_user(self, user_id: uuid.UUID, event: GatewayEvent) -> None:
        sockets = self._connections.get(user_id)
        if not sockets:
            return
        payload = event.model_dump(mode="json")
        for ws in list(sockets):
            await ws.send_json(payload)

    async def broadcast(self, event: GatewayEvent) -> None:
        payload = event.model_dump(mode="json")
        for sockets in list(self._connections.values()):
            for ws in list(sockets):
                await ws.send_json(payload)

    def voice_state_for_channel(self, channel_id: uuid.UUID) -> list[VoiceParticipantState]:
        return [s for s in self.voice_state.values() if s.channel_id == channel_id]

    def all_voice_state(self) -> list[VoiceParticipantState]:
        return list(self.voice_state.values())


manager = ConnectionManager()
