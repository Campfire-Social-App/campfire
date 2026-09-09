"""add custom profile decoration assets

Revision ID: ef91c6b8a420
Revises: d8a1f3c6b402
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "ef91c6b8a420"
down_revision: Union[str, None] = "d8a1f3c6b402"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "user_profiles",
        sa.Column(
            "custom_decoration_assets", sa.JSON(), server_default=sa.text("'{}'"), nullable=False
        ),
    )
    op.add_column("users", sa.Column("custom_identity_plate", sa.JSON(), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "custom_identity_plate")
    op.drop_column("user_profiles", "custom_decoration_assets")
