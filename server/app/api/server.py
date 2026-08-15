from fastapi import APIRouter

from app.core.deps import AdminUser, DbSession
from app.models.server_settings import SINGLETON_ID, ServerSettings
from app.schemas.server_settings import ServerSettingsRead, ServerSettingsUpdate

router = APIRouter(prefix="/api/server", tags=["server"])


async def _get_or_create_settings(db: DbSession) -> ServerSettings:
    settings_row = await db.get(ServerSettings, SINGLETON_ID)
    if settings_row is None:
        settings_row = ServerSettings(id=SINGLETON_ID)
        db.add(settings_row)
        await db.commit()
        await db.refresh(settings_row)
    return settings_row


@router.get("", response_model=ServerSettingsRead)
async def get_server_settings(db: DbSession) -> ServerSettings:
    return await _get_or_create_settings(db)


@router.patch("", response_model=ServerSettingsRead)
async def update_server_settings(
    payload: ServerSettingsUpdate, admin: AdminUser, db: DbSession
) -> ServerSettings:
    settings_row = await _get_or_create_settings(db)
    if payload.name is not None:
        settings_row.name = payload.name
    if payload.icon_url is not None:
        settings_row.icon_url = payload.icon_url
    db.add(settings_row)
    await db.commit()
    await db.refresh(settings_row)
    return settings_row
