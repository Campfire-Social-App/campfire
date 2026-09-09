"""add user identity profiles

Revision ID: f4d8a1b6c2e0
Revises: b4e91c73d5a2
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "f4d8a1b6c2e0"
down_revision: Union[str, None] = "b4e91c73d5a2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "user_profiles",
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("display_name", sa.String(64), nullable=True),
        sa.Column("bio", sa.Text(), nullable=True),
        sa.Column("custom_status", sa.String(128), nullable=True),
        sa.Column("profile_layout", sa.String(16), server_default="standard", nullable=False),
        sa.Column("accent_color", sa.String(7), server_default="#FF6A00", nullable=False),
        sa.Column("banner_type", sa.String(16), server_default="gradient", nullable=False),
        sa.Column("banner_color", sa.String(7), server_default="#FF6A00", nullable=False),
        sa.Column("banner_secondary_color", sa.String(7), server_default="#9A3412", nullable=False),
        sa.Column("background_type", sa.String(16), server_default="solid", nullable=False),
        sa.Column("avatar_decoration", sa.String(24), server_default="none", nullable=False),
        sa.Column("profile_effect", sa.String(24), server_default="none", nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("user_id"),
    )


def downgrade() -> None:
    op.drop_table("user_profiles")
