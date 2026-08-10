"""Add self-registration approval state to users.

Revision ID: 0006_user_self_registration
Revises: 0005_task_checklists
Create Date: 2026-08-10
"""
from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0006_user_self_registration"
down_revision: str | None = "0005_task_checklists"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    account_status = sa.Column(
        "account_status",
        sa.String(length=20),
        server_default="APPROVED",
        nullable=False,
    )
    reviewed_at = sa.Column(
        "reviewed_at",
        sa.DateTime(timezone=True),
        nullable=True,
    )
    reviewed_by_id = sa.Column("reviewed_by_id", sa.Uuid(), nullable=True)
    review_note = sa.Column(
        "review_note",
        sa.String(length=300),
        nullable=True,
    )

    if op.get_bind().dialect.name == "sqlite":
        with op.batch_alter_table("users", recreate="always") as batch_op:
            batch_op.add_column(account_status)
            batch_op.add_column(reviewed_at)
            batch_op.add_column(reviewed_by_id)
            batch_op.add_column(review_note)
            batch_op.create_index(
                op.f("ix_users_account_status"),
                ["account_status"],
            )
            batch_op.create_index(
                op.f("ix_users_reviewed_by_id"),
                ["reviewed_by_id"],
            )
            batch_op.create_foreign_key(
                "fk_users_reviewed_by_id_users",
                "users",
                ["reviewed_by_id"],
                ["id"],
                ondelete="SET NULL",
            )
    else:
        op.add_column("users", account_status)
        op.add_column("users", reviewed_at)
        op.add_column("users", reviewed_by_id)
        op.add_column("users", review_note)
        op.create_index(
            op.f("ix_users_account_status"),
            "users",
            ["account_status"],
        )
        op.create_index(
            op.f("ix_users_reviewed_by_id"),
            "users",
            ["reviewed_by_id"],
        )
        op.create_foreign_key(
            "fk_users_reviewed_by_id_users",
            "users",
            "users",
            ["reviewed_by_id"],
            ["id"],
            ondelete="SET NULL",
        )

    op.execute(
        "UPDATE users SET account_status = "
        "CASE WHEN is_active THEN 'APPROVED' ELSE 'SUSPENDED' END"
    )


def downgrade() -> None:
    if op.get_bind().dialect.name == "sqlite":
        with op.batch_alter_table("users", recreate="always") as batch_op:
            batch_op.drop_constraint(
                "fk_users_reviewed_by_id_users",
                type_="foreignkey",
            )
            batch_op.drop_index(op.f("ix_users_reviewed_by_id"))
            batch_op.drop_index(op.f("ix_users_account_status"))
            batch_op.drop_column("review_note")
            batch_op.drop_column("reviewed_by_id")
            batch_op.drop_column("reviewed_at")
            batch_op.drop_column("account_status")
    else:
        op.drop_constraint(
            "fk_users_reviewed_by_id_users",
            "users",
            type_="foreignkey",
        )
        op.drop_index(op.f("ix_users_reviewed_by_id"), table_name="users")
        op.drop_index(op.f("ix_users_account_status"), table_name="users")
        op.drop_column("users", "review_note")
        op.drop_column("users", "reviewed_by_id")
        op.drop_column("users", "reviewed_at")
        op.drop_column("users", "account_status")
