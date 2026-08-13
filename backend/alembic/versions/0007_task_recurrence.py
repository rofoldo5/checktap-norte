"""Add task recurrence and reminder fields.

Revision ID: 0007_task_recurrence
Revises: 0006_user_self_registration
Create Date: 2026-08-13

The migration is additive and intentionally tolerates columns/indexes created
by the short-lived v0.14.0 compatibility hook. This lets installations that
briefly ran that build rejoin the canonical Alembic history without data loss.
"""
from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "0007_task_recurrence"
down_revision: str | None = "0006_user_self_registration"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


RECURRENCE_INDEX_COLUMNS: dict[str, str] = {
    "ix_tasks_recurrence_type": "recurrence_type",
    "ix_tasks_next_occurrence_at": "next_occurrence_at",
    "ix_tasks_recurrence_series_id": "recurrence_series_id",
    "ix_tasks_is_recurrence_master": "is_recurrence_master",
    "ix_tasks_scheduled_for": "scheduled_for",
}

# Index names created by the temporary compatibility hook in v0.14.0.
LEGACY_COMPAT_INDEXES = {
    "idx_tasks_recurrence_type",
    "idx_tasks_next_occurrence_at",
    "idx_tasks_recurrence_series_id",
    "idx_tasks_is_recurrence_master",
    "idx_tasks_scheduled_for",
}


def _column_names(inspector: sa.Inspector) -> set[str]:
    return {column["name"] for column in inspector.get_columns("tasks")}


def _indexes(inspector: sa.Inspector) -> list[dict[str, object]]:
    return list(inspector.get_indexes("tasks"))


def _has_single_column_index(
    indexes: list[dict[str, object]],
    column_name: str,
) -> bool:
    for index in indexes:
        columns = index.get("column_names") or []
        if list(columns) == [column_name]:
            return True
    return False


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    if "tasks" not in inspector.get_table_names():
        raise RuntimeError(
            "No existe la tabla 'tasks'. Aplique primero las migraciones 0001-0006."
        )

    existing = _column_names(inspector)
    additions = [
        sa.Column(
            "recurrence_type",
            sa.String(length=20),
            nullable=False,
            server_default=sa.text("'NONE'"),
        ),
        sa.Column(
            "recurrence_interval",
            sa.Integer(),
            nullable=False,
            server_default=sa.text("1"),
        ),
        sa.Column("recurrence_unit", sa.String(length=12), nullable=True),
        sa.Column("recurrence_start_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "recurrence_timezone",
            sa.String(length=80),
            nullable=False,
            server_default=sa.text("'UTC'"),
        ),
        sa.Column("next_occurrence_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "notifications_enabled",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
        sa.Column(
            "reminder_minutes_before",
            sa.Integer(),
            nullable=False,
            server_default=sa.text("0"),
        ),
        sa.Column("recurrence_series_id", sa.String(length=36), nullable=True),
        sa.Column(
            "is_recurrence_master",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
        sa.Column("scheduled_for", sa.DateTime(timezone=True), nullable=True),
    ]

    for column in additions:
        if column.name not in existing:
            op.add_column("tasks", column)

    inspector = sa.inspect(bind)
    indexes = _indexes(inspector)
    for index_name, column_name in RECURRENCE_INDEX_COLUMNS.items():
        if not _has_single_column_index(indexes, column_name):
            op.create_index(index_name, "tasks", [column_name], unique=False)
            indexes.append({"name": index_name, "column_names": [column_name]})


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    if "tasks" not in inspector.get_table_names():
        return

    current_indexes = _indexes(inspector)
    removable_index_names = set(RECURRENCE_INDEX_COLUMNS) | LEGACY_COMPAT_INDEXES
    for index in current_indexes:
        index_name = index.get("name")
        if isinstance(index_name, str) and index_name in removable_index_names:
            op.drop_index(index_name, table_name="tasks")

    inspector = sa.inspect(bind)
    existing = _column_names(inspector)
    columns_to_drop = [
        "scheduled_for",
        "is_recurrence_master",
        "recurrence_series_id",
        "reminder_minutes_before",
        "notifications_enabled",
        "next_occurrence_at",
        "recurrence_timezone",
        "recurrence_start_at",
        "recurrence_unit",
        "recurrence_interval",
        "recurrence_type",
    ]

    if bind.dialect.name == "sqlite":
        with op.batch_alter_table("tasks") as batch_op:
            for column_name in columns_to_drop:
                if column_name in existing:
                    batch_op.drop_column(column_name)
    else:
        for column_name in columns_to_drop:
            if column_name in existing:
                op.drop_column("tasks", column_name)
