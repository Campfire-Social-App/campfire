"""add user moderation state

Revision ID: a9d2e4f6b801
Revises: f1a7c0b93e42
"""

from typing import Union

import sqlalchemy as sa
from alembic import op

revision: str = "a9d2e4f6b801"
down_revision: Union[str, None] = "f1a7c0b93e42"
branch_labels: Union[str, None] = None
depends_on: Union[str, None] = None


def upgrade() -> None:
    op.add_column(
        "users", sa.Column("is_banned", sa.Boolean(), server_default=sa.false(), nullable=False)
    )
    op.add_column("users", sa.Column("timed_out_until", sa.DateTime(timezone=True), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "timed_out_until")
    op.drop_column("users", "is_banned")
