"""FastAPI application entrypoint."""

from __future__ import annotations

import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from __PYTHON_PACKAGE__ import __version__
from __PYTHON_PACKAGE__.auth import service_secret_middleware
from __PYTHON_PACKAGE__.endpoints.health import router as health_router

app = FastAPI(
    title="__PROJECT_TITLE__ API",
    version=__version__,
    docs_url="/docs",
    redoc_url=None,
)

# Comma-separated origins, fall back to Vite dev server.
origins = [o.strip() for o in os.environ.get("ALLOWED_ORIGINS", "").split(",") if o.strip()] or [
    "http://localhost:5173"
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_methods=["GET", "POST", "PATCH"],
    allow_headers=["*"],
)

app.middleware("http")(service_secret_middleware)

app.include_router(health_router)
