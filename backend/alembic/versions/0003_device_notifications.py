"""Add device registrations for Firebase notifications.

Revision ID: 0003_device_notifications
Revises: 0002_offline_sync
Create Date: 2026-08-05
"""
from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "0003_device_notifications"
down_revision: str | None = "0002_offline_sync"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "device_registrations",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("registration_id", sa.Text(), nullable=False),
        sa.Column("registration_kind", sa.String(length=10), nullable=False),
        sa.Column("platform", sa.String(length=20), nullable=False),
        sa.Column("device_name", sa.String(length=120), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("last_seen_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("last_success_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_error", sa.Text(), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_device_registrations_is_active"),
        "device_registrations",
        ["is_active"],
    )
    op.create_index(
        op.f("ix_device_registrations_last_seen_at"),
        "device_registrations",
        ["last_seen_at"],
    )
    op.create_index(
        op.f("ix_device_registrations_registration_id"),
        "device_registrations",
        ["registration_id"],
        unique=True,
    )
    op.create_index(
        op.f("ix_device_registrations_user_id"),
        "device_registrations",
        ["user_id"],
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_device_registrations_user_id"),
        table_name="device_registrations",
    )
    op.drop_index(
        op.f("ix_device_registrations_registration_id"),
        table_name="device_registrations",
    )
    op.drop_index(
        op.f("ix_device_registrations_last_seen_at"),
        table_name="device_registrations",
    )
    op.drop_index(
        op.f("ix_device_registrations_is_active"),
        table_name="device_registrations",
    )
    op.drop_table("device_registrations")
