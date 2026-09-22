import os

from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .routers import dashboard, events, reports
from .telemetry import configure_telemetry, instrument_app

load_dotenv()

configure_telemetry("shoppulse-api")

app = FastAPI(title="ShopPulse API")
instrument_app(app)

cors_origins_raw = os.environ.get("CORS_ORIGINS", "*")
cors_origins = [o.strip() for o in cors_origins_raw.split(",")] if cors_origins_raw != "*" else ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_methods=["*"],
    allow_headers=["*"],
)


# The schema belongs to Alembic (`alembic upgrade head`, run by the db-migrate
# job before a rollout), not to the application process. Creating tables on
# startup raced between replicas and hid schema changes from review.


@app.get("/healthz")
async def healthz():
    return {"status": "ok"}


app.include_router(events.router, prefix="/api")
app.include_router(dashboard.router, prefix="/api")
app.include_router(reports.router, prefix="/api")
