import json

from livekit import api as livekit_api

from app.core.config import get_settings


def create_voice_token(
    *, room: str, identity: str, name: str, muted: bool = False, deafened: bool = False
) -> str:
    """Mint a LiveKit access token granting join/publish/subscribe on `room`."""
    settings = get_settings()
    token = (
        livekit_api.AccessToken(settings.livekit_api_key, settings.livekit_api_secret)
        .with_identity(identity)
        .with_name(name)
        .with_attributes({"muted": str(muted).lower(), "deafened": str(deafened).lower()})
        .with_grants(
            livekit_api.VideoGrants(
                room_join=True,
                room=room,
                can_publish=True,
                can_subscribe=True,
                # Used to propagate the participant's deafened state so other
                # clients can render the red audio icon next to their name.
                can_update_own_metadata=True,
            )
        )
    )
    return token.to_jwt()


def _api_url(url: str) -> str:
    """The browser connects over WebSocket, while LiveKit's admin API uses HTTP."""
    if url.startswith("wss://"):
        return f"https://{url.removeprefix('wss://')}"
    if url.startswith("ws://"):
        return f"http://{url.removeprefix('ws://')}"
    return url


def _livekit_api() -> livekit_api.LiveKitAPI:
    settings = get_settings()
    return livekit_api.LiveKitAPI(
        url=_api_url(settings.livekit_api_url or settings.livekit_url),
        api_key=settings.livekit_api_key,
        api_secret=settings.livekit_api_secret,
    )


async def mute_participant_microphone(*, identity: str, room: str) -> None:
    """Server-mute the participant's published microphone track, if present."""
    client = _livekit_api()
    try:
        participant = await client.room.get_participant(
            livekit_api.RoomParticipantIdentity(room=room, identity=identity)
        )
        microphone = next(
            (track for track in participant.tracks if track.source == livekit_api.TrackSource.MICROPHONE),
            None,
        )
        if microphone is None:
            raise ValueError("Participant has no published microphone")
        await client.room.mute_published_track(
            livekit_api.MuteRoomTrackRequest(
                room=room,
                identity=identity,
                track_sid=microphone.sid,
                muted=True,
            )
        )
    finally:
        await client.aclose()


async def request_participant_move(
    *, identity: str, source_room: str, destination_room: str, destination_name: str
) -> None:
    """Send a reliable, targeted moderation command over the active LiveKit room."""
    client = _livekit_api()
    try:
        payload = json.dumps(
            {
                "action": "move",
                "channel_id": destination_room,
                "channel_name": destination_name,
            }
        ).encode()
        await client.room.send_data(
            livekit_api.SendDataRequest(
                room=source_room,
                data=payload,
                kind=livekit_api.DataPacket.RELIABLE,
                destination_identities=[identity],
                topic="campfire.moderation",
            )
        )
    finally:
        await client.aclose()


async def disconnect_participant(*, identity: str, room: str) -> None:
    client = _livekit_api()
    try:
        await client.room.remove_participant(
            livekit_api.RoomParticipantIdentity(room=room, identity=identity)
        )
    finally:
        await client.aclose()


async def list_active_participants() -> list[tuple[str, str, str, bool, bool]]:
    """Return identity, display name, room and persisted voice controls."""
    client = _livekit_api()
    try:
        rooms = await client.room.list_rooms(livekit_api.ListRoomsRequest())
        active: list[tuple[str, str, str, bool, bool]] = []
        for room in rooms.rooms:
            participants = await client.room.list_participants(
                livekit_api.ListParticipantsRequest(room=room.name)
            )
            for participant in participants.participants:
                muted_attribute = participant.attributes.get("muted")
                microphone = next(
                    (
                        track
                        for track in participant.tracks
                        if track.source == livekit_api.TrackSource.MICROPHONE
                    ),
                    None,
                )
                # Participants connected by an older client do not carry the
                # attribute yet; their actual LiveKit track remains authoritative.
                muted = (
                    muted_attribute == "true"
                    if muted_attribute is not None
                    else microphone is None or microphone.muted
                )
                active.append(
                    (
                        participant.identity,
                        participant.name or participant.identity,
                        room.name,
                        muted,
                        participant.attributes.get("deafened") == "true",
                    )
                )
        return active
    finally:
        await client.aclose()


def get_webhook_receiver() -> livekit_api.WebhookReceiver:
    settings = get_settings()
    token_verifier = livekit_api.TokenVerifier(settings.livekit_api_key, settings.livekit_api_secret)
    return livekit_api.WebhookReceiver(token_verifier)
