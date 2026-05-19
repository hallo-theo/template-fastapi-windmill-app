"""Shared pytest fixtures.

The test client is configured with FRONTEND_SERVICE_SECRET set so auth
middleware works without a running database. Tests that hit /api/* pass the
service-secret header via the `authed` fixture; tests for auth failures use
the raw `client`.
"""

from __future__ import annotations

import os

import pytest
from fastapi.testclient import TestClient

TEST_SECRET = "test-secret-32-bytes-xxxxxxxxxxx"
TEST_USER = "test@hallotheo.de"

# Set before importing the app so config picks it up at module load time.
os.environ["FRONTEND_SERVICE_SECRET"] = TEST_SECRET


@pytest.fixture(scope="session")
def client() -> TestClient:
    from __PYTHON_PACKAGE__.main import app

    return TestClient(app, raise_server_exceptions=True)


@pytest.fixture(scope="session")
def authed() -> TestClient:
    """TestClient pre-loaded with service-secret + windmill-user headers."""
    from __PYTHON_PACKAGE__.main import app

    c = TestClient(app, raise_server_exceptions=True)
    c.headers.update(
        {"X-Service-Secret": TEST_SECRET, "X-Windmill-User": TEST_USER}
    )
    return c
