"""Service-secret auth middleware."""

from __future__ import annotations


def test_missing_secret_returns_401(client):
    res = client.get("/docs")
    assert res.status_code == 401
    assert res.json() == {"detail": "unauthorized"}


def test_wrong_secret_returns_401(client):
    res = client.get("/docs", headers={"X-Service-Secret": "wrong"})
    assert res.status_code == 401


def test_correct_secret_passes(authed):
    res = authed.get("/docs")
    assert res.status_code == 200
