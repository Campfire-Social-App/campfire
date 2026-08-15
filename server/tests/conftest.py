import os
from collections.abc import AsyncGenerator

import asyncpg
import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.db import Base, get_db
from app.main import create_app

TEST_DATABASE_URL = os.environ.get(
    "TEST_DATABASE_URL", "postgresql+asyncpg://campfire:campfire@localhost:5432/campfire_test"
)
MAINTENANCE_DATABASE_URL = os.environ.get(
    "MAINTENANCE_DATABASE_URL", "postgresql://campfire:campfire@localhost:5432/postgres"
)


async def _ensure_test_database_exists() -> None:
    conn = await asyncpg.connect(MAINTENANCE_DATABASE_URL)
    try:
        exists = await conn.fetchval("SELECT 1 FROM pg_database WHERE datname = 'campfire_test'")
        if not exists:
            await conn.execute("CREATE DATABASE campfire_test")
    finally:
        await conn.close()


@pytest_asyncio.fixture(scope="session")
async def db_engine():
    await _ensure_test_database_exists()
    engine = create_async_engine(TEST_DATABASE_URL)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await engine.dispose()


@pytest_asyncio.fixture
async def db_session(db_engine) -> AsyncGenerator[AsyncSession, None]:
    async with db_engine.connect() as connection:
        transaction = await connection.begin()
        session_maker = async_sessionmaker(
            bind=connection, expire_on_commit=False, join_transaction_mode="create_savepoint"
        )
        session = session_maker()
        try:
            yield session
        finally:
            await session.close()
            await transaction.rollback()


@pytest_asyncio.fixture
async def client(db_session: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    app = create_app()

    async def _override_get_db() -> AsyncGenerator[AsyncSession, None]:
        yield db_session

    app.dependency_overrides[get_db] = _override_get_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.fixture
def anyio_backend() -> str:
    return "asyncio"


@pytest_asyncio.fixture
async def admin_user(db_session: AsyncSession):
    from app.core.security import hash_password
    from app.models.user import User

    user = User(username="admin", password_hash=hash_password("admin1234"), is_admin=True)
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest_asyncio.fixture
async def admin_headers(admin_user) -> dict[str, str]:
    from app.core.security import create_access_token

    return {"Authorization": f"Bearer {create_access_token(admin_user.id)}"}
