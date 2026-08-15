from livekit import api as livekit_api

from app.core.config import get_settings


def create_voice_token(*, room: str, identity: str, name: str) -> str:
    """Mint a LiveKit access token granting join/publish/subscribe on `room`."""
    settings = get_settings()
    token = (
        livekit_api.AccessToken(settings.livekit_api_key, settings.livekit_api_secret)
        .with_identity(identity)
        .with_name(name)
        .with_grants(
            livekit_api.VideoGrants(
                room_join=True,
                room=room,
                can_publish=True,
                can_subscribe=True,
            )
        )
    )
    return token.to_jwt()


def get_webhook_receiver() -> livekit_api.WebhookReceiver:
    settings = get_settings()
    token_verifier = livekit_api.TokenVerifier(settings.livekit_api_key, settings.livekit_api_secret)
    return livekit_api.WebhookReceiver(token_verifier)
