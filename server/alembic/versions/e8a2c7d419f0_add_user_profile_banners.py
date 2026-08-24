"""add user profile banners

Revision ID: e8a2c7d419f0
Revises: a9d2e4f6b801
Create Date: 2026-08-23 12:00:00.000000-03:00
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "e8a2c7d419f0"
down_revision: Union[str, None] = "a9d2e4f6b801"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("users", sa.Column("banner_attachment_id", sa.UUID(), nullable=True))
    op.create_foreign_key(
        "fk_users_banner_attachment_id_attachments",
        "users",
        "attachments",
        ["banner_attachment_id"],
        ["id"],
        ondelete="SET NULL",
        use_alter=True,
    )


def downgrade() -> None:
    op.drop_constraint(
        "fk_users_banner_attachment_id_attachments", "users", type_="foreignkey"
    )
    op.drop_column("users", "banner_attachment_id")
