"""Public, unauthenticated liveness probe.

Cloud Run uses this for healthchecks. Listed in ``auth._OPEN_PATHS``, so it
does not require the service secret.
"""

from __future__ import annotations

from fastapi import APIRouter

router = APIRouter()


@router.get("/healthz")
async def healthz():
    return {"status": "ok"}
