"""legacy admin actions checkpoint

Revision ID: a7d4100f5e33
Revises: f1a7c0b93e42

Some development databases were stamped with this revision by an older
moderation branch. The branch created the now-retired ``admin_actions`` table,
but its migration file was not retained when moderation moved to user state.
Keeping this no-op checkpoint reconnects those databases to the canonical
history without deleting their audit data. Fresh databases do not need the
retired table.
"""
from typing import Sequence, Union


revision: str = "a7d4100f5e33"
down_revision: Union[str, None] = "f1a7c0b93e42"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
