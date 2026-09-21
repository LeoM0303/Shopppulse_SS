# app.database reads its configuration at import time, so the environment has to be in place
# before app.main is imported. The engine is lazy, so a dummy DSN is enough and no test here
# ever opens a database connection.
import os

os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://test:test@localhost:5432/test")
os.environ.setdefault("REDIS_URL", "redis://localhost:6379/0")
os.environ.setdefault("SERVICE_BUS_CONNECTION_STRING", "")

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.dependencies import get_db, get_redis  # noqa: E402
from app.main import app  # noqa: E402


class FakeRedis:
    """Stand-in for the async redis client, recording writes instead of performing them."""

    def __init__(self):
        self.value = None
        self.writes = []

    async def get(self, key):
        return self.value

    async def set(self, key, value, ex=None):
        self.writes.append((key, value, ex))


@pytest.fixture
def redis():
    return FakeRedis()


@pytest.fixture
def client(redis):
    # TestClient is deliberately not used as a context manager: entering it runs the startup
    # hook, which creates tables against a real database.
    app.dependency_overrides[get_redis] = lambda: redis
    app.dependency_overrides[get_db] = lambda: None
    yield TestClient(app)
    app.dependency_overrides.clear()
