"""What makes this service host *bots* rather than one bot.

A bot declares the commands it answers to; the registry maps a command name to
the bot that owns it and builds the descriptor list the clients use for their
`/` autocomplete. Adding a second bot is a `register(...)` call in main.py.
"""

from dataclasses import dataclass
from typing import Protocol, runtime_checkable


@dataclass(frozen=True)
class CommandSpec:
    name: str
    description: str
    # Argument hint shown next to the name in the composer, e.g. "<url ou busca>".
    usage: str = ""
    # Whether the caller has to be in a voice channel. The bot enforces it; the
    # flag only lets a client explain the requirement before the round trip.
    requires_voice: bool = False


@dataclass(frozen=True)
class CommandContext:
    """Everything a command gets to know, all of it established by the core
    server — nothing here was chosen by the client that typed the command."""

    user_id: str
    username: str
    text_channel_id: str
    voice_channel_id: str | None
    args: str


class CommandError(Exception):
    """A refusal the person who typed the command should see as a toast.

    Anything that can be decided immediately — not in a call, missing argument,
    empty queue — belongs here. Results that arrive later are posted in the
    channel instead.
    """

    def __init__(self, detail: str, status_code: int = 400) -> None:
        super().__init__(detail)
        self.detail = detail
        self.status_code = status_code


@runtime_checkable
class Bot(Protocol):
    name: str

    def commands(self) -> list[CommandSpec]: ...

    async def start(self) -> None: ...

    async def stop(self) -> None: ...

    async def run(self, command: str, context: CommandContext) -> None: ...


class Registry:
    def __init__(self) -> None:
        self._bots: list[Bot] = []
        self._by_command: dict[str, Bot] = {}
        self._specs: dict[str, CommandSpec] = {}

    def register(self, bot: Bot) -> None:
        for spec in bot.commands():
            if spec.name in self._by_command:
                raise ValueError(
                    f"Command /{spec.name} is claimed by both "
                    f"{self._by_command[spec.name].name} and {bot.name}"
                )
            self._by_command[spec.name] = bot
            self._specs[spec.name] = spec
        self._bots.append(bot)

    @property
    def bots(self) -> list[Bot]:
        return list(self._bots)

    def specs(self) -> list[CommandSpec]:
        return list(self._specs.values())

    def bot_for(self, command: str) -> Bot | None:
        return self._by_command.get(command)

    async def start_all(self) -> None:
        for bot in self._bots:
            await bot.start()

    async def stop_all(self) -> None:
        for bot in self._bots:
            await bot.stop()
