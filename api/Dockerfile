# syntax=docker/dockerfile:1
#
# Build context is the REPO ROOT (not ./api). api/ is a uv workspace member;
# the lockfile lives at the repo root. Build with:
#
#     docker build -f api/Dockerfile -t __PROJECT_SLUG__-api:dev .
#
FROM python:3.12-slim-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates && rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:0.5 /uv /uvx /usr/local/bin/

WORKDIR /app

# Resolve dependencies first against just the workspace metadata, so the
# heavy deps layer is cacheable across code-only changes.
COPY pyproject.toml uv.lock* ./
COPY api/pyproject.toml ./api/pyproject.toml
RUN uv sync --frozen --no-dev --no-install-workspace --package __PYTHON_PACKAGE__ 2>/dev/null \
 || uv sync --no-dev --no-install-workspace --package __PYTHON_PACKAGE__

# Install the api package itself (--no-editable bakes the code into
# site-packages so the image is self-contained).
COPY api/src ./api/src
RUN uv sync --no-dev --no-editable --package __PYTHON_PACKAGE__

ENV PATH="/app/.venv/bin:${PATH}"
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1

EXPOSE 8080
CMD ["uvicorn", "__PYTHON_PACKAGE__.main:app", "--host", "0.0.0.0", "--port", "8080"]
