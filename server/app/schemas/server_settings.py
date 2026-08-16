from pydantic import BaseModel, ConfigDict


class ServerSettingsRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    name: str
    icon_url: str | None
    # Deployment limit rather than a stored setting — the client needs it to turn
    # away an oversized file before spending an upload on it.
    max_upload_bytes: int


class ServerSettingsUpdate(BaseModel):
    name: str | None = None
    icon_url: str | None = None
