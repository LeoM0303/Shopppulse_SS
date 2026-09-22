"""create sales_events

Revision ID: 0001
Revises:
Create Date: 2026-09-22

Baseline of the schema that used to be created by SQLAlchemy's create_all at
startup. An environment that already has the table from that era should be
brought into the migration history with `alembic stamp 0001` rather than by
running this revision.
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "sales_events",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("store_id", sa.String(length=64), nullable=False),
        sa.Column("product_id", sa.String(length=64), nullable=False),
        sa.Column("product_name", sa.String(length=256), nullable=False),
        sa.Column(
            "event_type",
            sa.Enum("sale", "return", name="event_type_enum"),
            nullable=False,
        ),
        sa.Column("quantity", sa.Integer(), nullable=False),
        sa.Column("unit_price", sa.Numeric(precision=10, scale=2), nullable=False),
        sa.Column("occurred_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )

    # Every dashboard query filters on the last 24 hours and then groups by
    # product or store, which is exactly what these two cover.
    op.create_index("ix_sales_events_occurred_at", "sales_events", ["occurred_at"])
    op.create_index(
        "ix_sales_events_product_occurred_at",
        "sales_events",
        ["product_id", "occurred_at"],
    )


def downgrade() -> None:
    op.drop_index("ix_sales_events_product_occurred_at", table_name="sales_events")
    op.drop_index("ix_sales_events_occurred_at", table_name="sales_events")
    op.drop_table("sales_events")
    sa.Enum(name="event_type_enum").drop(op.get_bind())
