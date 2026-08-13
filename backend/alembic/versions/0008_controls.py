"""Add generic control sections, checks, reminders and history.

Revision ID: 0008_controls
Revises: 0007_task_recurrence
Create Date: 2026-08-13
"""
from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "0008_controls"
down_revision: str | None = "0007_task_recurrence"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "control_sections",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("icon_key", sa.String(length=40), nullable=False, server_default=sa.text("'folder'")),
        sa.Column("department_id", sa.Uuid(), nullable=False),
        sa.Column("created_by_id", sa.Uuid(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("version", sa.Integer(), nullable=False, server_default=sa.text("1")),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["created_by_id"], ["users.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["department_id"], ["departments.id"], ondelete="RESTRICT"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_control_sections_name"), "control_sections", ["name"])
    op.create_index(op.f("ix_control_sections_department_id"), "control_sections", ["department_id"])
    op.create_index(op.f("ix_control_sections_created_by_id"), "control_sections", ["created_by_id"])
    op.create_index(op.f("ix_control_sections_is_active"), "control_sections", ["is_active"])

    op.create_table(
        "control_checks",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("section_id", sa.Uuid(), nullable=False),
        sa.Column("title", sa.String(length=180), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("reference", sa.String(length=300), nullable=True),
        sa.Column("contact", sa.String(length=300), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("priority", sa.String(length=10), nullable=False, server_default=sa.text("'MEDIA'")),
        sa.Column("status", sa.String(length=20), nullable=False, server_default=sa.text("'PENDIENTE'")),
        sa.Column("due_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("timezone", sa.String(length=80), nullable=False, server_default=sa.text("'UTC'")),
        sa.Column("recurrence_type", sa.String(length=20), nullable=False, server_default=sa.text("'NONE'")),
        sa.Column("recurrence_interval", sa.Integer(), nullable=False, server_default=sa.text("1")),
        sa.Column("recurrence_unit", sa.String(length=12), nullable=True),
        sa.Column("recurrence_anchor_day", sa.Integer(), nullable=True),
        sa.Column("recurrence_anchor_month", sa.Integer(), nullable=True),
        sa.Column("version", sa.Integer(), nullable=False, server_default=sa.text("1")),
        sa.Column("created_by_id", sa.Uuid(), nullable=False),
        sa.Column("completed_by_id", sa.Uuid(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["section_id"], ["control_sections.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["created_by_id"], ["users.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["completed_by_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    for column in (
        "section_id",
        "title",
        "priority",
        "status",
        "due_at",
        "recurrence_type",
        "created_by_id",
        "completed_by_id",
        "completed_at",
    ):
        op.create_index(op.f(f"ix_control_checks_{column}"), "control_checks", [column])

    op.create_table(
        "control_check_assignees",
        sa.Column("check_id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("assigned_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["check_id"], ["control_checks.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("check_id", "user_id"),
    )

    op.create_table(
        "control_check_reminders",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("check_id", sa.Uuid(), nullable=False),
        sa.Column("minutes_before", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["check_id"], ["control_checks.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("check_id", "minutes_before", name="uq_control_check_reminder"),
    )
    op.create_index(op.f("ix_control_check_reminders_check_id"), "control_check_reminders", ["check_id"])

    op.create_table(
        "control_check_history",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("check_id", sa.Uuid(), nullable=False),
        sa.Column("completed_by_id", sa.Uuid(), nullable=True),
        sa.Column("due_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("next_due_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("completion_notes", sa.Text(), nullable=True),
        sa.ForeignKeyConstraint(["check_id"], ["control_checks.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["completed_by_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_control_check_history_check_id"), "control_check_history", ["check_id"])
    op.create_index(op.f("ix_control_check_history_completed_by_id"), "control_check_history", ["completed_by_id"])
    op.create_index(op.f("ix_control_check_history_completed_at"), "control_check_history", ["completed_at"])


def downgrade() -> None:
    op.drop_table("control_check_history")
    op.drop_table("control_check_reminders")
    op.drop_table("control_check_assignees")
    op.drop_table("control_checks")
    op.drop_table("control_sections")
