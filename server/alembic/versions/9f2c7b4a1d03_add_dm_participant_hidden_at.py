"""add per-user DM visibility

Revision ID: 9f2c7b4a1d03
Revises: ef91c6b8a420
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "9f2c7b4a1d03"
down_revision: Union[str, None] = "ef91c6b8a420"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "dm_participants",
        sa.Column("hidden_at", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("dm_participants", "hidden_at")
