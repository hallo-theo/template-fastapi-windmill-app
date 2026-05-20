"""Shared-secret auth + Windmill identity propagation.

Every non-/healthz request must carry ``X-Service-Secret`` matching the env
var ``FRONTEND_SERVICE_SECRET``. The Windmill ``call_api`` runnable attaches
it in production; the Vite dev proxy attaches it locally. The browser never
sees the secret.

``X-Windmill-User`` / ``X-Windmill-Username`` are informational headers for
audit stamping. They're forged only by the trusted runnable/proxy.
Authorization is the shared secret; identity is informational.
"""

from __future__ import annotations

import hmac
import logging
import os

from fastapi import Request
from fastapi.responses import JSONResponse

log = logging.getLogger("__PYTHON_PACKAGE__")

_OPEN_PATHS: frozenset[str] = frozenset({"/healthz"})
_FRONTEND_SECRET = os.environ.get("FRONTEND_SERVICE_SECRET", "")

NO_AUTHOR = "no_author"

_GENERIC_DENIED = {"detail": "unauthorized"}


def _deny(request: Request, *, reason: str, status_code: int = 401) -> JSONResponse:
    client_host = request.client.host if request.client else "-"
    log.warning(
        "auth_denied reason=%s path=%s method=%s client=%s status=%d",
        reason,
        request.url.path,
        request.method,
        client_host,
        status_code,
    )
    return JSONResponse(_GENERIC_DENIED, status_code=status_code)


async def service_secret_middleware(request: Request, call_next):
    """Constant-time compare on ``X-Service-Secret``."""
    path = request.url.path
    if path in _OPEN_PATHS:
        return await call_next(request)

    if not _FRONTEND_SECRET:
        return _deny(request, reason="frontend_secret_unset", status_code=500)
    provided = request.headers.get("x-service-secret", "")
    if not hmac.compare_digest(provided, _FRONTEND_SECRET):
        return _deny(request, reason="frontend_secret_mismatch")

    request.state.windmill_user = request.headers.get("x-windmill-user", "").strip() or NO_AUTHOR
    request.state.windmill_username = request.headers.get("x-windmill-username", "").strip() or None
    return await call_next(request)


def current_user(request: Request) -> str:
    """FastAPI dependency: the Windmill identity stamped by the middleware."""
    return getattr(request.state, "windmill_user", NO_AUTHOR) or NO_AUTHOR


def current_username(request: Request) -> str | None:
    """FastAPI dependency: the Windmill short username (display only)."""
    return getattr(request.state, "windmill_username", None)
