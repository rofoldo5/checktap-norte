from __future__ import annotations

import logging

from sqlalchemy import inspect, text

from app.core.database import engine

logger = logging.getLogger(__name__)


def ensure_recurring_task_schema() -> None:
    """Idempotent compatibility migration for deployments without Alembic files.

    The repository snapshot used by the mobile project does not ship the Alembic
    versions directory, so this small additive migration keeps existing SQLite
    and PostgreSQL installations compatible without dropping or rewriting data.
    """

    inspector = inspect(engine)
    if "tasks" not in inspector.get_table_names():
        return

    columns = {column["name"] for column in inspector.get_columns("tasks")}
    dialect = engine.dialect.name
    datetime_type = "TIMESTAMP WITH TIME ZONE" if dialect == "postgresql" else "DATETIME"
    boolean_type = "BOOLEAN"

    additions = {
        "recurrence_type": "VARCHAR(20) NOT NULL DEFAULT 'NONE'",
        "recurrence_interval": "INTEGER NOT NULL DEFAULT 1",
        "recurrence_unit": "VARCHAR(12)",
        "recurrence_start_at": datetime_type,
        "recurrence_timezone": "VARCHAR(80) NOT NULL DEFAULT 'UTC'",
        "next_occurrence_at": datetime_type,
        "notifications_enabled": f"{boolean_type} NOT NULL DEFAULT FALSE",
        "reminder_minutes_before": "INTEGER NOT NULL DEFAULT 0",
        "recurrence_series_id": "VARCHAR(36)",
        "is_recurrence_master": f"{boolean_type} NOT NULL DEFAULT FALSE",
        "scheduled_for": datetime_type,
    }

    with engine.begin() as connection:
        for name, ddl in additions.items():
            if name in columns:
                continue
            logger.info("Agregando columna tasks.%s", name)
            connection.execute(text(f"ALTER TABLE tasks ADD COLUMN {name} {ddl}"))

        for index_name, column_name in (
            ("idx_tasks_recurrence_type", "recurrence_type"),
            ("idx_tasks_next_occurrence_at", "next_occurrence_at"),
            ("idx_tasks_recurrence_series_id", "recurrence_series_id"),
            ("idx_tasks_is_recurrence_master", "is_recurrence_master"),
            ("idx_tasks_scheduled_for", "scheduled_for"),
        ):
            try:
                connection.execute(
                    text(
                        f"CREATE INDEX IF NOT EXISTS {index_name} "
                        f"ON tasks ({column_name})"
                    )
                )
            except Exception:
                logger.exception("No fue posible crear el indice %s", index_name)
