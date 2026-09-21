# app.main reads DATABASE_URL at import time; the value is never connected to in these tests.
import os

os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://test:test@localhost:5432/test")
