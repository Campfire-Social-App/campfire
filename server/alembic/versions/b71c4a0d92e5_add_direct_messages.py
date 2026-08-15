"""add direct messages

Revision ID: b71c4a0d92e5
Revises: 322bafb0e771
Create Date: 2026-08-15 20:10:00.000000+00:00

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'b71c4a0d92e5'
down_revision: Union[str, None] = '322bafb0e771'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Adding an enum value inside a transaction is fine on PostgreSQL 12+ as long
    # as nothing in this same transaction stores that value — nothing here does.
    op.execute("ALTER TYPE channel_type ADD VALUE IF NOT EXISTS 'DM'")

    op.add_column('channels', sa.Column('dm_key', sa.String(length=73), nullable=True))
    op.create_index(op.f('ix_channels_dm_key'), 'channels', ['dm_key'], unique=True)

    op.create_table(
        'dm_participants',
        sa.Column('channel_id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('last_read_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['channel_id'], ['channels.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('channel_id', 'user_id'),
    )
    op.create_index(op.f('ix_dm_participants_user_id'), 'dm_participants', ['user_id'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_dm_participants_user_id'), table_name='dm_participants')
    op.drop_table('dm_participants')
    op.drop_index(op.f('ix_channels_dm_key'), table_name='channels')
    op.drop_column('channels', 'dm_key')

    # PostgreSQL can't drop a value from an enum, so the type is rebuilt without
    # 'DM'. Any conversation still present has to go with it — nothing outside a
    # DM references those rows, and the feature is being removed either way.
    op.execute("DELETE FROM channels WHERE type = 'DM'")
    op.execute("ALTER TYPE channel_type RENAME TO channel_type_old")
    op.execute("CREATE TYPE channel_type AS ENUM ('TEXT', 'VOICE')")
    op.execute(
        "ALTER TABLE channels ALTER COLUMN type TYPE channel_type "
        "USING type::text::channel_type"
    )
    op.execute("DROP TYPE channel_type_old")
