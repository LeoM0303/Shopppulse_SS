import json
import logging
import os
import uuid
from datetime import datetime, timezone
from typing import Optional

from azure.servicebus.aio import ServiceBusClient
from azure.servicebus import ServiceBusMessage
from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..database import AsyncSessionLocal
from ..dependencies import get_db
from ..models import SalesEvent
from ..schemas import EventPayload, EventsResponse, SalesEventOut

logger = logging.getLogger(__name__)
router = APIRouter()

SERVICE_BUS_CONNECTION_STRING = os.environ.get("SERVICE_BUS_CONNECTION_STRING", "")
SERVICE_BUS_QUEUE_NAME = os.environ.get("SERVICE_BUS_QUEUE_NAME", "sales-events")


@router.post("/events", response_model=SalesEventOut, status_code=201)
async def submit_event(payload: EventPayload, db: AsyncSession = Depends(get_db)):
    event_id = uuid.uuid4()
    occurred_at = payload.occurred_at or datetime.now(timezone.utc)

    event = SalesEvent(
        id=event_id,
        store_id=payload.store_id,
        product_id=payload.product_id,
        product_name=payload.product_name,
        event_type=payload.event_type,
        quantity=payload.quantity,
        unit_price=payload.unit_price,
        occurred_at=occurred_at,
        created_at=datetime.now(timezone.utc),
    )
    db.add(event)
    await db.commit()
    await db.refresh(event)

    try:
        msg_body = json.dumps(
            {
                "event_id": str(event_id),
                "store_id": payload.store_id,
                "product_id": payload.product_id,
                "product_name": payload.product_name,
                "event_type": payload.event_type,
                "quantity": payload.quantity,
                "unit_price": float(payload.unit_price),
                "occurred_at": occurred_at.isoformat(),
            }
        )
        async with ServiceBusClient.from_connection_string(SERVICE_BUS_CONNECTION_STRING) as sb_client:
            async with sb_client.get_queue_sender(SERVICE_BUS_QUEUE_NAME) as sender:
                sb_msg = ServiceBusMessage(msg_body, correlation_id=str(event_id))
                await sender.send_messages(sb_msg)
    except Exception:
        logger.exception("Failed to publish event %s to Service Bus", event_id)

    return event


@router.get("/events", response_model=EventsResponse)
async def list_events(
    store_id: Optional[str] = Query(None),
    event_type: Optional[str] = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
):
    base_query = select(SalesEvent)
    count_query = select(func.count()).select_from(SalesEvent)

    if store_id:
        base_query = base_query.where(SalesEvent.store_id == store_id)
        count_query = count_query.where(SalesEvent.store_id == store_id)
    if event_type:
        base_query = base_query.where(SalesEvent.event_type == event_type)
        count_query = count_query.where(SalesEvent.event_type == event_type)

    total_result = await db.execute(count_query)
    total = total_result.scalar_one()

    items_result = await db.execute(
        base_query.order_by(SalesEvent.occurred_at.desc()).limit(limit).offset(offset)
    )
    items = items_result.scalars().all()

    return EventsResponse(total=total, items=items)
