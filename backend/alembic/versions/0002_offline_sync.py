"""Add offline synchronization support.

Revision ID: 0002_offline_sync
Revises: 0001_initial
Create Date: 2026-08-04
"""
from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "0002_offline_sync"
down_revision: str | None = "0001_initial"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "tasks",
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
    )

    op.create_table(
        "processed_operations",
        sa.Column("operation_id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("operation_type", sa.String(length=30), nullable=False),
        sa.Column("entity_id", sa.Uuid(), nullable=False),
        sa.Column("result_status", sa.String(length=20), nullable=False),
        sa.Column("response_json", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("operation_id"),
    )
    op.create_index(
        op.f("ix_processed_operations_created_at"),
        "processed_operations",
        ["created_at"],
    )
    op.create_index(
        op.f("ix_processed_operations_entity_id"),
        "processed_operations",
        ["entity_id"],
    )
    op.create_index(
        op.f("ix_processed_operations_user_id"),
        "processed_operations",
        ["user_id"],
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_processed_operations_user_id"),
        table_name="processed_operations",
    )
    op.drop_index(
        op.f("ix_processed_operations_entity_id"),
        table_name="processed_operations",
    )
    op.drop_index(
        op.f("ix_processed_operations_created_at"),
        table_name="processed_operations",
    )
    op.drop_table("processed_operations")
    op.drop_column("tasks", "version")
