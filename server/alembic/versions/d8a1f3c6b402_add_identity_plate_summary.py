"""add identity plate summary to users

Revision ID: d8a1f3c6b402
Revises: c5e8a2d4f901
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "d8a1f3c6b402"
down_revision: Union[str, None] = "c5e8a2d4f901"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("identity_plate_decoration", sa.String(32), server_default="none", nullable=False),
    )
    op.execute(
        "UPDATE users SET identity_plate_decoration = user_profiles.identity_plate_decoration "
        "FROM user_profiles WHERE users.id = user_profiles.user_id"
    )


def downgrade() -> None:
    op.drop_column("users", "identity_plate_decoration")
