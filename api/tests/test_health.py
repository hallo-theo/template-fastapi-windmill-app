"""Liveness endpoint — public, no secret required."""

from __future__ import annotations


def test_healthz_returns_200(client):
    res = client.get("/healthz")
    assert res.status_code == 200


def test_healthz_body_has_status(client):
    res = client.get("/healthz")
    assert res.json() == {"status": "ok"}
