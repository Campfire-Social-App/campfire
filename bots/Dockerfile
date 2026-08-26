FROM python:3.12-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# ffmpeg is the decoder: yt-dlp hands over a stream URL, ffmpeg turns it into
# the raw 48 kHz stereo PCM that LiveKit's AudioSource takes.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN pip install --no-cache-dir poetry==2.3.2 \
    && poetry config virtualenvs.create false

COPY pyproject.toml ./
RUN poetry install --no-root --only main --no-interaction --no-ansi

COPY . .

EXPOSE 8100

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8100"]
