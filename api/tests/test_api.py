import json


def test_healthz_reports_ok(client):
    response = client.get("/healthz")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_dashboard_is_served_from_cache_when_present(client, redis):
    redis.value = json.dumps(
        {
            "updated_at": "2026-01-01T00:00:00+00:00",
            "period_hours": 24,
            "total_sales": 3,
            "total_returns": 1,
            "net_revenue": 42.5,
            "top_products": [],
            "alerts": [],
        }
    )

    body = client.get("/api/dashboard").json()

    assert body["source"] == "cache"
    assert body["net_revenue"] == 42.5


def test_submit_event_rejects_non_positive_quantity(client):
    response = client.post(
        "/api/events",
        json={
            "store_id": "s1",
            "product_id": "p1",
            "product_name": "Widget",
            "event_type": "sale",
            "quantity": 0,
            "unit_price": 9.99,
        },
    )

    assert response.status_code == 422


def test_submit_event_rejects_unknown_event_type(client):
    response = client.post(
        "/api/events",
        json={
            "store_id": "s1",
            "product_id": "p1",
            "product_name": "Widget",
            "event_type": "refund",
            "quantity": 1,
            "unit_price": 9.99,
        },
    )

    assert response.status_code == 422
