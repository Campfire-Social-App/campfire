"""add user is_bot

Revision ID: b4e91c73d5a2
Revises: e8a2c7d419f0
"""

from typing import Union

import sqlalchemy as sa
from alembic import op

revision: str = "b4e91c73d5a2"
down_revision: Union[str, None] = "e8a2c7d419f0"
branch_labels: Union[str, None] = None
depends_on: Union[str, None] = None


def upgrade() -> None:
    op.add_column(
        "users", sa.Column("is_bot", sa.Boolean(), server_default=sa.false(), nullable=False)
    )


def downgrade() -> None:
    op.drop_column("users", "is_bot")
