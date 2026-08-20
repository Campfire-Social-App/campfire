"""add user avatars

Revision ID: c3d742e8f105
Revises: d239f4c8a671
Create Date: 2026-08-19 12:00:00.000000-03:00
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "c3d742e8f105"
down_revision: Union[str, None] = "d239f4c8a671"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("users", sa.Column("avatar_attachment_id", sa.UUID(), nullable=True))
    op.create_foreign_key(
        "fk_users_avatar_attachment_id_attachments",
        "users",
        "attachments",
        ["avatar_attachment_id"],
        ["id"],
        ondelete="SET NULL",
        use_alter=True,
    )


def downgrade() -> None:
    op.drop_constraint(
        "fk_users_avatar_attachment_id_attachments", "users", type_="foreignkey"
    )
    op.drop_column("users", "avatar_attachment_id")
