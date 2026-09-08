"""separate profile cosmetic selections

Revision ID: c5e8a2d4f901
Revises: 81ce43d7b520
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "c5e8a2d4f901"
down_revision: Union[str, None] = "81ce43d7b520"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "user_profiles",
        sa.Column("avatar_frame_decoration", sa.String(32), server_default="none", nullable=False),
    )
    op.add_column(
        "user_profiles",
        sa.Column("identity_plate_decoration", sa.String(32), server_default="none", nullable=False),
    )
    # Preserve the avatar portion of previously selected complete packs.
    op.execute(
        "UPDATE user_profiles SET avatar_frame_decoration = profile_decoration "
        "WHERE profile_decoration <> 'none'"
    )


def downgrade() -> None:
    op.drop_column("user_profiles", "identity_plate_decoration")
    op.drop_column("user_profiles", "avatar_frame_decoration")
