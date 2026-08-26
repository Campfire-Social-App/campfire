"""The yt-dlp music bot: queue, transport controls, and feedback in the chat."""

import asyncio
import logging

from app.bots.ytdlp.player import Player, Track, TrackUnavailable, resolve
from app.campfire.client import CampfireClient
from app.campfire.gateway import GatewayConnection
from app.core.registry import CommandContext, CommandError, CommandSpec

logger = logging.getLogger(__name__)

_COMMANDS = [
    CommandSpec(
        name="play",
        description="Toca uma faixa no seu canal de voz (ou põe na fila)",
        usage="<url ou busca>",
        requires_voice=True,
    ),
    CommandSpec(name="pause", description="Pausa a faixa atual", requires_voice=True),
    CommandSpec(name="resume", description="Retoma a faixa pausada", requires_voice=True),
    CommandSpec(name="skip", description="Pula para a próxima da fila", requires_voice=True),
    CommandSpec(name="stop", description="Para tudo e sai do canal de voz", requires_voice=True),
    CommandSpec(name="queue", description="Mostra a fila atual"),
]


class YtDlpBot:
    name = "ytdlp"

    def __init__(
        self,
        *,
        client: CampfireClient,
        gateway: GatewayConnection,
        ffmpeg_path: str,
        livekit_url_override: str = "",
    ) -> None:
        self._client = client
        self._gateway = gateway
        self._ffmpeg_path = ffmpeg_path
        self._livekit_url_override = livekit_url_override
        # One player per voice channel: two groups in two calls are two
        # independent queues, the way any music bot behaves.
        self._players: dict[str, Player] = {}
        # Where each call's feedback goes: the text channel its last command was
        # typed in, so a /skip asked elsewhere answers where it was asked.
        self._feedback_channels: dict[str, str] = {}
        # In-flight /play resolutions, kept alive until they report themselves.
        self._pending: set[asyncio.Task[None]] = set()
        self._players_lock = asyncio.Lock()

    def commands(self) -> list[CommandSpec]:
        return list(_COMMANDS)

    async def start(self) -> None:
        # The gateway signs in on its own and retries with backoff, so this is
        # all it takes to come online — and a core server that is not up yet
        # costs a retry rather than a failed boot.
        self._gateway.start()

    async def stop(self) -> None:
        await self._gateway.stop()
        for task in list(self._pending):
            task.cancel()
        for player in list(self._players.values()):
            await player.close()
        self._players.clear()
        self._feedback_channels.clear()

    # -------------------------------------------------------------- dispatch

    async def run(self, command: str, context: CommandContext) -> None:
        handler = getattr(self, f"_cmd_{command}", None)
        if handler is None:
            raise CommandError(f"/{command} não existe", status_code=404)
        await handler(context)

    def _voice_channel(self, context: CommandContext) -> str:
        if context.voice_channel_id is None:
            raise CommandError("Entre num canal de voz primeiro")
        return context.voice_channel_id

    async def _player_for(self, voice_channel_id: str, text_channel_id: str) -> Player:
        """The player for a call, created and connected on first use."""
        async with self._players_lock:
            player = self._players.get(voice_channel_id)
            if player is None:
                player = Player(
                    voice_channel_id=voice_channel_id,
                    ffmpeg_path=self._ffmpeg_path,
                    on_event=lambda text: self._say(voice_channel_id, text),
                )
                self._players[voice_channel_id] = player
            self._feedback_channels[voice_channel_id] = text_channel_id

        if not player.connected:
            credentials = await self._client.voice_token(voice_channel_id)
            url = self._livekit_url_override or credentials["url"]
            await player.connect(url=url, token=credentials["token"])
        return player

    async def _say(self, voice_channel_id: str, text: str) -> None:
        """Posts a line of feedback where this call's last command came from."""
        channel_id = self._feedback_channels.get(voice_channel_id)
        if channel_id is None:
            return
        try:
            await self._client.send_message(channel_id, text)
        except Exception:
            logger.warning("Could not post feedback to %s", channel_id, exc_info=True)

    def _existing_player(self, context: CommandContext) -> Player:
        voice_channel_id = self._voice_channel(context)
        player = self._players.get(voice_channel_id)
        if player is None or (player.current is None and not player.queue):
            raise CommandError("Não tem nada tocando neste canal de voz")
        self._feedback_channels[voice_channel_id] = context.text_channel_id
        return player

    # -------------------------------------------------------------- commands

    async def _cmd_play(self, context: CommandContext) -> None:
        voice_channel_id = self._voice_channel(context)
        query = context.args.strip()
        if not query:
            raise CommandError("Diga o que tocar: `/play <url ou busca>`")

        player = await self._player_for(voice_channel_id, context.text_channel_id)
        # Resolving hits the network and can take seconds, so the outcome is a
        # message in the channel rather than the command's HTTP response. The
        # task is held onto: the event loop only keeps a weak reference, so a
        # bare create_task can be collected mid-flight.
        task = asyncio.create_task(
            self._play(player, query, context), name=f"play-{voice_channel_id}"
        )
        self._pending.add(task)
        task.add_done_callback(self._pending.discard)

    async def _play(self, player: Player, query: str, context: CommandContext) -> None:
        try:
            track = await resolve(query, context.username)
        except TrackUnavailable as exc:
            await self._say(player.voice_channel_id, f"⚠️ Não consegui achar `{query}`: {exc}")
            await self._leave_if_idle(player)
            return

        try:
            position = await player.enqueue(track)
        except Exception:
            logger.exception("Could not enqueue %s", track.title)
            await self._say(player.voice_channel_id, f"⚠️ Falhei ao tocar **{track.title}**")
            await self._leave_if_idle(player)
            return

        if position == 0:
            await self._say(player.voice_channel_id, f"▶️ Tocando **{track.label()}**")
        else:
            await self._say(
                player.voice_channel_id, f"➕ **{track.label()}** entrou na fila (posição {position})"
            )

    async def _leave_if_idle(self, player: Player) -> None:
        """A /play that never produced a track shouldn't leave the bot parked in
        an empty call."""
        if player.current is None and not player.queue:
            await player.stop()
            await self._forget(player.voice_channel_id)

    async def _forget(self, voice_channel_id: str) -> None:
        async with self._players_lock:
            self._players.pop(voice_channel_id, None)
            self._feedback_channels.pop(voice_channel_id, None)

    async def _cmd_pause(self, context: CommandContext) -> None:
        player = self._existing_player(context)
        if not await player.pause():
            raise CommandError("Já está pausado")
        await self._say(player.voice_channel_id, "⏸️ Pausado")

    async def _cmd_resume(self, context: CommandContext) -> None:
        player = self._existing_player(context)
        if not await player.resume():
            raise CommandError("Não está pausado")
        await self._say(player.voice_channel_id, "▶️ Retomando")

    async def _cmd_skip(self, context: CommandContext) -> None:
        player = self._existing_player(context)
        result = await player.skip()
        if result is None:
            raise CommandError("Não tem nada tocando")
        skipped, followup = result
        await self._say(player.voice_channel_id, f"⏭️ Pulei **{skipped.title}**")
        if followup:
            await self._say(player.voice_channel_id, followup)
        if player.current is None:
            await self._forget(player.voice_channel_id)

    async def _cmd_stop(self, context: CommandContext) -> None:
        player = self._existing_player(context)
        await player.stop()
        await self._say(player.voice_channel_id, "⏹️ Parei e saí do canal de voz.")
        await self._forget(player.voice_channel_id)

    async def _cmd_queue(self, context: CommandContext) -> None:
        # The only command that works from outside a call: it reads, it does not
        # touch the audio. Without a voice channel it reports on nothing at all.
        voice_channel_id = context.voice_channel_id
        player = self._players.get(voice_channel_id) if voice_channel_id else None
        if player is None or (player.current is None and not player.queue):
            raise CommandError("A fila está vazia")

        self._feedback_channels[player.voice_channel_id] = context.text_channel_id
        await self._say(player.voice_channel_id, _format_queue(player.current, player.queue, player.paused))


def _format_queue(current: Track | None, queue: list[Track], paused: bool) -> str:
    lines = []
    if current is not None:
        marker = "⏸️" if paused else "▶️"
        lines.append(f"{marker} **{current.label()}** — pedida por {current.requested_by}")
    for position, track in enumerate(queue, start=1):
        lines.append(f"{position}. {track.label()} — pedida por {track.requested_by}")
    return "\n".join(lines)
