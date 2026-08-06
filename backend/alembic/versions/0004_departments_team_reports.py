"""Add departments, team notifications, multiple assignees and daily reports.

Revision ID: 0004_departments_team_reports
Revises: 0003_device_notifications
Create Date: 2026-08-05
"""
from collections.abc import Sequence
from datetime import UTC, datetime
import os
from uuid import uuid4

from alembic import op
import sqlalchemy as sa

revision: str = "0004_departments_team_reports"
down_revision: str | None = "0003_device_notifications"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "departments",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("name"),
    )
    op.create_index(op.f("ix_departments_is_active"), "departments", ["is_active"])
    op.create_index(op.f("ix_departments_name"), "departments", ["name"], unique=True)

    op.create_table(
        "department_members",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("department_id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("role", sa.String(length=20), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["department_id"], ["departments.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("department_id", "user_id", name="uq_department_member"),
    )
    op.create_index(
        op.f("ix_department_members_department_id"),
        "department_members",
        ["department_id"],
    )
    op.create_index(
        op.f("ix_department_members_is_active"),
        "department_members",
        ["is_active"],
    )
    op.create_index(
        op.f("ix_department_members_user_id"),
        "department_members",
        ["user_id"],
    )

    op.add_column("tasks", sa.Column("department_id", sa.Uuid(), nullable=True))
    op.create_index(op.f("ix_tasks_department_id"), "tasks", ["department_id"])

    op.create_table(
        "task_assignees",
        sa.Column("task_id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("assigned_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["task_id"], ["tasks.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("task_id", "user_id"),
    )

    op.create_table(
        "daily_reports",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("department_id", sa.Uuid(), nullable=False),
        sa.Column("report_date", sa.Date(), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column("file_path", sa.Text(), nullable=True),
        sa.Column("file_size", sa.Integer(), nullable=False),
        sa.Column("created_count", sa.Integer(), nullable=False),
        sa.Column("completed_count", sa.Integer(), nullable=False),
        sa.Column("pending_count", sa.Integer(), nullable=False),
        sa.Column("in_progress_count", sa.Integer(), nullable=False),
        sa.Column("error", sa.Text(), nullable=True),
        sa.Column("generated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["department_id"], ["departments.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "department_id",
            "report_date",
            name="uq_daily_report_department_date",
        ),
    )
    op.create_index(
        op.f("ix_daily_reports_department_id"),
        "daily_reports",
        ["department_id"],
    )
    op.create_index(
        op.f("ix_daily_reports_generated_at"),
        "daily_reports",
        ["generated_at"],
    )
    op.create_index(
        op.f("ix_daily_reports_report_date"),
        "daily_reports",
        ["report_date"],
    )
    op.create_index(op.f("ix_daily_reports_status"), "daily_reports", ["status"])

    op.create_table(
        "notification_events",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("department_id", sa.Uuid(), nullable=False),
        sa.Column("event_type", sa.String(length=40), nullable=False),
        sa.Column("actor_user_id", sa.Uuid(), nullable=True),
        sa.Column("task_id", sa.Uuid(), nullable=True),
        sa.Column("report_id", sa.Uuid(), nullable=True),
        sa.Column("title", sa.String(length=180), nullable=False),
        sa.Column("body", sa.String(length=500), nullable=False),
        sa.Column("data_json", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["actor_user_id"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["department_id"], ["departments.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["report_id"], ["daily_reports.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["task_id"], ["tasks.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    for column in (
        "actor_user_id",
        "created_at",
        "department_id",
        "event_type",
        "report_id",
        "task_id",
    ):
        op.create_index(
            op.f(f"ix_notification_events_{column}"),
            "notification_events",
            [column],
        )

    op.create_table(
        "notification_deliveries",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("event_id", sa.Uuid(), nullable=False),
        sa.Column("device_registration_id", sa.Uuid(), nullable=True),
        sa.Column("user_id", sa.Uuid(), nullable=True),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column("firebase_message_id", sa.Text(), nullable=True),
        sa.Column("error", sa.Text(), nullable=True),
        sa.Column("sent_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["device_registration_id"],
            ["device_registrations.id"],
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(["event_id"], ["notification_events.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    for column in ("device_registration_id", "event_id", "sent_at", "status", "user_id"):
        op.create_index(
            op.f(f"ix_notification_deliveries_{column}"),
            "notification_deliveries",
            [column],
        )

    bind = op.get_bind()
    now = datetime.now(UTC)
    department_id = uuid4()
    default_name = os.getenv("DEFAULT_DEPARTMENT_NAME", "Programacion").strip() or "Programacion"

    departments = sa.table(
        "departments",
        sa.column("id", sa.Uuid()),
        sa.column("name", sa.String()),
        sa.column("is_active", sa.Boolean()),
        sa.column("created_at", sa.DateTime(timezone=True)),
        sa.column("updated_at", sa.DateTime(timezone=True)),
    )
    bind.execute(
        departments.insert().values(
            id=department_id,
            name=default_name,
            is_active=True,
            created_at=now,
            updated_at=now,
        )
    )

    users = sa.table(
        "users",
        sa.column("id", sa.Uuid()),
        sa.column("is_active", sa.Boolean()),
    )
    members = sa.table(
        "department_members",
        sa.column("id", sa.Uuid()),
        sa.column("department_id", sa.Uuid()),
        sa.column("user_id", sa.Uuid()),
        sa.column("role", sa.String()),
        sa.column("is_active", sa.Boolean()),
        sa.column("created_at", sa.DateTime(timezone=True)),
        sa.column("updated_at", sa.DateTime(timezone=True)),
    )
    user_ids = list(bind.execute(sa.select(users.c.id)).scalars())
    if user_ids:
        bind.execute(
            members.insert(),
            [
                {
                    "id": uuid4(),
                    "department_id": department_id,
                    "user_id": user_id,
                    "role": "MEMBER",
                    "is_active": True,
                    "created_at": now,
                    "updated_at": now,
                }
                for user_id in user_ids
            ],
        )

    tasks = sa.table(
        "tasks",
        sa.column("id", sa.Uuid()),
        sa.column("department_id", sa.Uuid()),
        sa.column("assigned_to_id", sa.Uuid()),
    )
    bind.execute(tasks.update().values(department_id=department_id))

    task_assignees = sa.table(
        "task_assignees",
        sa.column("task_id", sa.Uuid()),
        sa.column("user_id", sa.Uuid()),
        sa.column("assigned_at", sa.DateTime(timezone=True)),
    )
    existing_assignments = list(
        bind.execute(
            sa.select(tasks.c.id, tasks.c.assigned_to_id).where(
                tasks.c.assigned_to_id.is_not(None)
            )
        )
    )
    if existing_assignments:
        bind.execute(
            task_assignees.insert(),
            [
                {
                    "task_id": row.id,
                    "user_id": row.assigned_to_id,
                    "assigned_at": now,
                }
                for row in existing_assignments
            ],
        )

    with op.batch_alter_table("tasks") as batch_op:
        batch_op.alter_column("department_id", existing_type=sa.Uuid(), nullable=False)
        batch_op.create_foreign_key(
            "fk_tasks_department_id_departments",
            "departments",
            ["department_id"],
            ["id"],
            ondelete="RESTRICT",
        )


def downgrade() -> None:
    with op.batch_alter_table("tasks") as batch_op:
        batch_op.drop_constraint("fk_tasks_department_id_departments", type_="foreignkey")
    op.drop_index(op.f("ix_tasks_department_id"), table_name="tasks")
    op.drop_column("tasks", "department_id")

    for column in ("user_id", "status", "sent_at", "event_id", "device_registration_id"):
        op.drop_index(
            op.f(f"ix_notification_deliveries_{column}"),
            table_name="notification_deliveries",
        )
    op.drop_table("notification_deliveries")

    for column in ("task_id", "report_id", "event_type", "department_id", "created_at", "actor_user_id"):
        op.drop_index(
            op.f(f"ix_notification_events_{column}"),
            table_name="notification_events",
        )
    op.drop_table("notification_events")

    op.drop_index(op.f("ix_daily_reports_status"), table_name="daily_reports")
    op.drop_index(op.f("ix_daily_reports_report_date"), table_name="daily_reports")
    op.drop_index(op.f("ix_daily_reports_generated_at"), table_name="daily_reports")
    op.drop_index(op.f("ix_daily_reports_department_id"), table_name="daily_reports")
    op.drop_table("daily_reports")
    op.drop_table("task_assignees")

    op.drop_index(op.f("ix_department_members_user_id"), table_name="department_members")
    op.drop_index(op.f("ix_department_members_is_active"), table_name="department_members")
    op.drop_index(op.f("ix_department_members_department_id"), table_name="department_members")
    op.drop_table("department_members")
    op.drop_index(op.f("ix_departments_name"), table_name="departments")
    op.drop_index(op.f("ix_departments_is_active"), table_name="departments")
    op.drop_table("departments")
