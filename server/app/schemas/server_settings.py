from pydantic import BaseModel, ConfigDict


class ServerSettingsRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    name: str
    icon_url: str | None


class ServerSettingsUpdate(BaseModel):
    name: str | None = None
    icon_url: str | None = None
