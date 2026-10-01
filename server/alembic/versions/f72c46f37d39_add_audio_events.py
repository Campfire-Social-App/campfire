"""add audio_events

Revision ID: f72c46f37d39
Revises: 9f2c7b4a1d03
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql


revision: str = "f72c46f37d39"
down_revision: Union[str, None] = "9f2c7b4a1d03"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "audio_events",
        sa.Column("id", sa.BigInteger(), sa.Identity(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=True),
        sa.Column("channel_id", sa.UUID(), nullable=True),
        sa.Column("session_id", sa.UUID(), nullable=True),
        sa.Column("source", sa.String(length=16), nullable=False),
        sa.Column("platform", sa.String(length=16), nullable=True),
        sa.Column("event_type", sa.String(length=64), nullable=False),
        sa.Column("detail", postgresql.JSONB(), server_default="{}", nullable=False),
        sa.Column("client_ts", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["channel_id"], ["channels.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_audio_events_user_id"), "audio_events", ["user_id"], unique=False)
    op.create_index(op.f("ix_audio_events_channel_id"), "audio_events", ["channel_id"], unique=False)
    op.create_index(op.f("ix_audio_events_session_id"), "audio_events", ["session_id"], unique=False)
    op.create_index(op.f("ix_audio_events_event_type"), "audio_events", ["event_type"], unique=False)
    op.create_index(op.f("ix_audio_events_created_at"), "audio_events", ["created_at"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_audio_events_created_at"), table_name="audio_events")
    op.drop_index(op.f("ix_audio_events_event_type"), table_name="audio_events")
    op.drop_index(op.f("ix_audio_events_session_id"), table_name="audio_events")
    op.drop_index(op.f("ix_audio_events_channel_id"), table_name="audio_events")
    op.drop_index(op.f("ix_audio_events_user_id"), table_name="audio_events")
    op.drop_table("audio_events")
