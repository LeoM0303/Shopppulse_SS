from datetime import datetime, timezone


async def recompute_summary(pool) -> dict:
    async with pool.acquire() as conn:
        products = await conn.fetch("""
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

        totals = await conn.fetchrow("""
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

        store_rates = await conn.fetch("""
            SELECT
                store_id,
                SUM(CASE WHEN event_type = 'return' THEN 1 ELSE 0 END)::float /
                    NULLIF(COUNT(*), 0) AS return_rate
            FROM sales_events
            WHERE occurred_at >= NOW() - INTERVAL '24 hours'
            GROUP BY store_id
        """)

    alerts = []
    for row in store_rates:
        if row["return_rate"] and row["return_rate"] > 0.1:
            alerts.append(
                {"level": "warning", "message": f"Return rate above 10% for {row['store_id']}"}
            )

    return {
        "updated_at": datetime.now(timezone.utc).isoformat(),
        "period_hours": 24,
        "total_sales": int(totals["total_sales"] or 0),
        "total_returns": int(totals["total_returns"] or 0),
        "net_revenue": float(totals["net_revenue"] or 0),
        "top_products": [
            {
                "product_id": r["product_id"],
                "product_name": r["product_name"],
                "units_sold": int(r["units_sold"] or 0),
                "revenue": float(r["revenue"] or 0),
            }
            for r in products
        ],
        "alerts": alerts,
    }
