import asyncio
import json
import logging
import os

import asyncpg
import redis.asyncio as aioredis
from aiohttp import web
from azure.servicebus.aio import ServiceBusClient
from azure.servicebus import ServiceBusReceiveMode
from dotenv import load_dotenv

from urllib.parse import parse_qsl, urlencode, urlparse, urlunparse

from .processor import recompute_summary

load_dotenv()

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)

DATABASE_URL = os.environ["DATABASE_URL"]
REDIS_URL = os.environ.get("REDIS_URL", "redis://localhost:6379/0")
SERVICE_BUS_CONNECTION_STRING = os.environ.get("SERVICE_BUS_CONNECTION_STRING", "")
SERVICE_BUS_QUEUE_NAME = os.environ.get("SERVICE_BUS_QUEUE_NAME", "sales-events")
REDIS_KEY = "dashboard:summary"
REDIS_TTL = 300


def _asyncpg_connect_args(database_url: str) -> tuple[str, dict]:
    """Strip SQLAlchemy/asyncpg URL scheme and move ssl* query params to asyncpg kwargs."""
    dsn = database_url.replace("postgresql+asyncpg://", "postgresql://")
    parsed = urlparse(dsn)
    params = dict(parse_qsl(parsed.query, keep_blank_values=True))
    ssl_value = params.pop("ssl", None) or params.pop("sslmode", None)
    clean_query = urlencode(params) if params else ""
    clean_dsn = urlunparse(parsed._replace(query=clean_query))

    connect_kwargs: dict = {}
    if ssl_value in ("require", "verify-full", "verify-ca", "prefer"):
        connect_kwargs["ssl"] = "require" if ssl_value == "require" else ssl_value
    elif ssl_value == "disable":
        connect_kwargs["ssl"] = False

    return clean_dsn, connect_kwargs


_pg_dsn, _pg_connect_kwargs = _asyncpg_connect_args(DATABASE_URL)


async def health_handler(request):
    return web.Response(text='{"status":"ok"}', content_type="application/json")


async def run_health_server():
    app = web.Application()
    app.router.add_get("/healthz", health_handler)
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, "0.0.0.0", 8001)
    await site.start()
    logger.info("Health server started on :8001")


async def run_worker(pool: asyncpg.Pool, redis: aioredis.Redis):
    retry_delay = 5
    while True:
        try:
            async with ServiceBusClient.from_connection_string(SERVICE_BUS_CONNECTION_STRING) as sb_client:
                receiver = sb_client.get_queue_receiver(
                    queue_name=SERVICE_BUS_QUEUE_NAME,
                    receive_mode=ServiceBusReceiveMode.PEEK_LOCK,
                )
                async with receiver:
                    logger.info("Worker listening on queue '%s'", SERVICE_BUS_QUEUE_NAME)
                    retry_delay = 5  # reset on successful connect
                    while True:
                        messages = await receiver.receive_messages(max_wait_time=5, max_message_count=10)
                        for msg in messages:
                            try:
                                body = b"".join(msg.body).decode()
                                json.loads(body)
                                await receiver.complete_message(msg)
                                summary = await recompute_summary(pool)
                                await redis.set(REDIS_KEY, json.dumps(summary), ex=REDIS_TTL)
                                logger.info("Dashboard summary recomputed and cached")
                            except Exception:
                                logger.exception("Error processing message; abandoning")
                                try:
                                    await receiver.abandon_message(msg)
                                except Exception:
                                    pass
        except Exception as e:
            logger.warning("Service Bus unavailable (%s); retrying in %ds", e, retry_delay)
            await asyncio.sleep(retry_delay)
            retry_delay = min(retry_delay * 2, 60)


async def main():
    pool = await asyncpg.create_pool(_pg_dsn, min_size=2, max_size=10, **_pg_connect_kwargs)
    redis = aioredis.from_url(REDIS_URL, decode_responses=True)

    await run_health_server()
    await run_worker(pool, redis)


if __name__ == "__main__":
    asyncio.run(main())
