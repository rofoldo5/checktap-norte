"""Add task checklists and checklist items.

Revision ID: 0005_task_checklists
Revises: 0004_departments_team_reports
Create Date: 2026-08-06
"""
from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "0005_task_checklists"
down_revision: str | None = "0004_departments_team_reports"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "task_checklists",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("task_id", sa.Uuid(), nullable=False),
        sa.Column("title", sa.String(length=180), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("created_by_id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["created_by_id"], ["users.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["task_id"], ["tasks.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_task_checklists_created_by_id"),
        "task_checklists",
        ["created_by_id"],
    )
    op.create_index(
        op.f("ix_task_checklists_task_id"),
        "task_checklists",
        ["task_id"],
    )

    op.create_table(
        "task_checklist_items",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("checklist_id", sa.Uuid(), nullable=False),
        sa.Column("title", sa.String(length=300), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("is_completed", sa.Boolean(), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("created_by_id", sa.Uuid(), nullable=False),
        sa.Column("completed_by_id", sa.Uuid(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["checklist_id"], ["task_checklists.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["completed_by_id"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["created_by_id"], ["users.id"], ondelete="RESTRICT"),
        sa.PrimaryKeyConstraint("id"),
    )
    for column in ("checklist_id", "completed_at", "completed_by_id", "created_by_id"):
        op.create_index(
            op.f(f"ix_task_checklist_items_{column}"),
            "task_checklist_items",
            [column],
        )


def downgrade() -> None:
    op.drop_table("task_checklist_items")
    op.drop_table("task_checklists")
