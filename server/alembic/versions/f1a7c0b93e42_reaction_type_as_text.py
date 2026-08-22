"""reaction type as text

Revision ID: f1a7c0b93e42
Revises: c3d742e8f105
Create Date: 2026-08-20 23:20:00.000000-03:00

`message_reactions.type` was created as the PostgreSQL enum `reaction_type`
(labels LIKE/LOVE/LAUGH), but the model now declares it `String(80)` — reaction
keys are meant to be extensible, so a closed enum cannot hold them. Nothing
reconciled the two, so every insert reached the database as a varchar against an
enum column and came back:

    DatatypeMismatchError: column "type" is of type reaction_type
    but expression is of type character varying

which surfaced as a 500 on `PUT /api/messages/{id}/reactions/{type}` — reacting
was broken on any deployment built by the reactions migration.

The column becomes text, and the rows written while it was an enum are folded to
the lowercase keys the API speaks, so an old 'LIKE' and a new 'like' are not
counted as two different reactions.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "f1a7c0b93e42"
down_revision: Union[str, None] = "c3d742e8f105"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.alter_column(
        "message_reactions",
        "type",
        type_=sa.String(length=80),
        existing_nullable=False,
        postgresql_using="lower(type::text)",
    )
    # Nothing else references it; leaving it behind would make a fresh database
    # and an upgraded one differ.
    op.execute("DROP TYPE IF EXISTS reaction_type")


def downgrade() -> None:
    reaction_type = postgresql.ENUM("LIKE", "LOVE", "LAUGH", name="reaction_type", create_type=False)
    reaction_type.create(op.get_bind(), checkfirst=True)
    # Anything outside the three built-ins has no enum label to go back to, so
    # it is dropped rather than blocking the downgrade.
    op.execute("DELETE FROM message_reactions WHERE lower(type) NOT IN ('like', 'love', 'laugh')")
    op.alter_column(
        "message_reactions",
        "type",
        type_=reaction_type,
        existing_nullable=False,
        postgresql_using="upper(type)::reaction_type",
    )
