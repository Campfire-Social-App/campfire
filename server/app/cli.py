"""Operator CLI. Usage: python -m app.cli create-admin --username <u> --password <p>"""

import argparse
import asyncio
import sys

from app.db import async_session_maker
from app.services.bootstrap import ensure_admin


async def create_admin(username: str, password: str) -> None:
    async with async_session_maker() as db:
        await ensure_admin(db, username, password)
        print(f"Admin '{username}' pronto.")


def main() -> None:
    parser = argparse.ArgumentParser(prog="python -m app.cli")
    subparsers = parser.add_subparsers(dest="command", required=True)

    create_admin_parser = subparsers.add_parser("create-admin", help="Cria (ou promove) o primeiro admin")
    create_admin_parser.add_argument("--username", required=True)
    create_admin_parser.add_argument("--password", required=True)

    args = parser.parse_args()

    if args.command == "create-admin":
        if len(args.password) < 8:
            print("A senha deve ter ao menos 8 caracteres.", file=sys.stderr)
            sys.exit(1)
        asyncio.run(create_admin(args.username, args.password))


if __name__ == "__main__":
    main()
