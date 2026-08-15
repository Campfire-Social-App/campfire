from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.models.user import User


async def ensure_admin(db: AsyncSession, username: str, password: str) -> User:
    """Create the user as admin, or promote it if it already exists."""
    existing = (await db.execute(select(User).where(User.username == username))).scalar_one_or_none()
    if existing is not None:
        existing.is_admin = True
        db.add(existing)
        await db.commit()
        await db.refresh(existing)
        return existing

    user = User(username=username, password_hash=hash_password(password), is_admin=True)
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user
