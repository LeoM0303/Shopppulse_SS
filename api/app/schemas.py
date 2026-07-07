from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal
from typing import Literal, Optional

from pydantic import BaseModel, Field


class EventPayload(BaseModel):
    store_id: str
    product_id: str
    product_name: str
    event_type: Literal["sale", "return"]
    quantity: int = Field(ge=1)
    unit_price: Decimal = Field(gt=0)
    occurred_at: Optional[datetime] = None


class SalesEventOut(BaseModel):
    id: uuid.UUID
    store_id: str
    product_id: str
    product_name: str
    event_type: str
    quantity: int
    unit_price: Decimal
    occurred_at: datetime
    created_at: datetime

    model_config = {"from_attributes": True}


class EventsResponse(BaseModel):
    total: int
    items: list[SalesEventOut]


class TopProduct(BaseModel):
    product_id: str
    product_name: str
    units_sold: int
    revenue: float


class Alert(BaseModel):
    level: Literal["warning", "error"]
    message: str


class DashboardSummary(BaseModel):
    updated_at: str
    period_hours: int
    total_sales: int
    total_returns: int
    net_revenue: float
    top_products: list[TopProduct]
    alerts: list[Alert]
    source: Optional[Literal["cache", "db"]] = None
