"""add user display name summary

Revision ID: 6b2e74f1a930
Revises: f4d8a1b6c2e0
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "6b2e74f1a930"
down_revision: Union[str, None] = "f4d8a1b6c2e0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("users", sa.Column("display_name", sa.String(64), nullable=True))
    op.execute(
        "UPDATE users SET display_name = user_profiles.display_name "
        "FROM user_profiles WHERE user_profiles.user_id = users.id"
    )


def downgrade() -> None:
    op.drop_column("users", "display_name")
