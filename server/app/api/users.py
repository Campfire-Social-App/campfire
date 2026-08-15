from fastapi import APIRouter
from sqlalchemy import select

from app.core.deps import CurrentUser, DbSession
from app.models.user import User
from app.schemas.user import UserRead

router = APIRouter(prefix="/api/users", tags=["users"])


@router.get("", response_model=list[UserRead])
async def list_users(user: CurrentUser, db: DbSession) -> list[User]:
    """All registered members. Single-server MVP: no per-channel privacy boundary,
    so any authenticated member can see the full member list (matches PLANO.md scope)."""
    result = await db.execute(select(User).order_by(User.username))
    return list(result.scalars().all())
