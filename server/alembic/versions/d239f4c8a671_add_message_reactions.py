"""add message reactions

Revision ID: d239f4c8a671
Revises: b71c4a0d92e5
Create Date: 2026-08-18 01:45:00.000000-03:00
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision: str = "d239f4c8a671"
down_revision: Union[str, None] = "b71c4a0d92e5"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    reaction_type = postgresql.ENUM(
        "LIKE", "LOVE", "LAUGH", name="reaction_type", create_type=False
    )
    reaction_type.create(op.get_bind(), checkfirst=True)
    op.create_table(
        "message_reactions",
        sa.Column("message_id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("type", reaction_type, nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False
        ),
        sa.ForeignKeyConstraint(["message_id"], ["messages.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("message_id", "user_id", "type"),
    )


def downgrade() -> None:
    op.drop_table("message_reactions")
    reaction_type = postgresql.ENUM(name="reaction_type", create_type=False)
    reaction_type.drop(op.get_bind(), checkfirst=True)
