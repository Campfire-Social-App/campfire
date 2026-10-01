FROM python:3.12-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

RUN pip install --no-cache-dir poetry==2.3.2 \
    && poetry config virtualenvs.create false

# Without the lock file, poetry re-resolves from pyproject.toml's ranges on
# every build — unpinned, so a newer release can silently change what gets
# installed. That's exactly what broke production on 2026-10-01: a fresh
# resolve picked SQLAlchemy 2.1, which — unlike the locked 2.0.x — doesn't
# pull in greenlet, the dependency its asyncio engine (app/db.py) needs.
COPY pyproject.toml poetry.lock ./
RUN poetry install --no-root --only main --no-interaction --no-ansi

COPY . .

RUN mkdir -p /data/uploads

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
