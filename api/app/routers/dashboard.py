import json
import logging
from datetime import datetime, timezone

import redis.asyncio as aioredis
from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from ..dependencies import get_db, get_redis
from ..schemas import DashboardSummary

logger = logging.getLogger(__name__)
router = APIRouter()

REDIS_KEY = "dashboard:summary"


async def _compute_from_db(db: AsyncSession) -> dict:
    rows = await db.execute(
        text("""
            SELECT
                product_id,
                MAX(product_name) AS product_name,
                SUM(CASE WHEN event_type = 'sale' THEN quantity ELSE 0 END) AS units_sold,
                SUM(
                    CASE WHEN event_type = 'sale' THEN unit_price * quantity
                         WHEN event_type = 'return' THEN -(unit_price * quantity)
                         ELSE 0 END
                ) AS revenue
            FROM sales_events
            WHERE occurred_at >= NOW() - INTERVAL '24 hours'
            GROUP BY product_id
            ORDER BY units_sold DESC
            LIMIT 10
        """)
    )
    products = rows.mappings().all()

    totals = await db.execute(
        text("""
            SELECT
                SUM(CASE WHEN event_type = 'sale' THEN 1 ELSE 0 END) AS total_sales,
                SUM(CASE WHEN event_type = 'return' THEN 1 ELSE 0 END) AS total_returns,
                SUM(
                    CASE WHEN event_type = 'sale' THEN unit_price * quantity
                         WHEN event_type = 'return' THEN -(unit_price * quantity)
                         ELSE 0 END
                ) AS net_revenue
            FROM sales_events
            WHERE occurred_at >= NOW() - INTERVAL '24 hours'
        """)
    )
    t = totals.mappings().one()

    store_rates = await db.execute(
        text("""
            SELECT
                store_id,
                SUM(CASE WHEN event_type = 'return' THEN 1 ELSE 0 END)::float /
                    NULLIF(COUNT(*), 0) AS return_rate
            FROM sales_events
            WHERE occurred_at >= NOW() - INTERVAL '24 hours'
            GROUP BY store_id
        """)
    )

    alerts = []
    for row in store_rates.mappings().all():
        if row["return_rate"] and row["return_rate"] > 0.1:
            alerts.append(
                {
                    "level": "warning",
                    "message": f"Return rate above 10% for {row['store_id']}",
                }
            )

    return {
        "updated_at": datetime.now(timezone.utc).isoformat(),
        "period_hours": 24,
        "total_sales": int(t["total_sales"] or 0),
        "total_returns": int(t["total_returns"] or 0),
        "net_revenue": float(t["net_revenue"] or 0),
        "top_products": [
            {
                "product_id": p["product_id"],
                "product_name": p["product_name"],
                "units_sold": int(p["units_sold"] or 0),
                "revenue": float(p["revenue"] or 0),
            }
            for p in products
        ],
        "alerts": alerts,
    }


@router.get("/dashboard")
async def get_dashboard(
    redis: aioredis.Redis = Depends(get_redis),
    db: AsyncSession = Depends(get_db),
):
    cached = await redis.get(REDIS_KEY)
    if cached:
        data = json.loads(cached)
        data["source"] = "cache"
        return data

    data = await _compute_from_db(db)
    data["source"] = "db"
    return data
