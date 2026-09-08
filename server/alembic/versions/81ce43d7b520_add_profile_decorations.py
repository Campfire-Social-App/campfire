"""add profile decorations

Revision ID: 81ce43d7b520
Revises: 6b2e74f1a930
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "81ce43d7b520"
down_revision: Union[str, None] = "6b2e74f1a930"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "user_profiles",
        sa.Column("profile_decoration", sa.String(32), server_default="none", nullable=False),
    )


def downgrade() -> None:
    op.drop_column("user_profiles", "profile_decoration")
