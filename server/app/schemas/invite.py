import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class InviteCreateRequest(BaseModel):
    max_uses: int | None = Field(default=None, ge=1)
    expires_in_hours: int | None = Field(default=None, ge=1)


class InviteRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    code: str
    created_by_id: uuid.UUID
    max_uses: int | None
    uses_count: int
    expires_at: datetime | None
    created_at: datetime
