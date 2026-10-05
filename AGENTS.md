# __PROJECT_TITLE__ — agent guide

The single agent guide for this repo (`CLAUDE.md` is a pointer here). Keep it
short. **Every rule in the Guardrails section is enforced by a named check —
not aspirational.** If a task would require breaking one, stop and ask instead
of working around it.

## Repo shape

| Path | What it is |
|------|------------|
| `api/` | FastAPI backend. Python 3.12, uv workspace. Pure data server. |
| `app/__PROJECT_SLUG__.raw_app/` | Windmill full-code app (React + Vite + TypeScript). Calls the API via `backend.call_api`. |
| `app/__PROJECT_SLUG__.raw_app/backend/` | Windmill runnables. `call_api.ts` attaches `X-Service-Secret` + `X-Windmill-User` server-side. `whoami.ts` returns the viewer's identity from `WM_USERNAME`. |
| `app/__PROJECT_SLUG__.raw_app/wmill.ts` | Dev stub for the Windmill-generated module. Windmill auto-replaces this at `wmill app push`. |

## Make targets

```
make install         uv sync + npm install
make dev             FastAPI :8000 + Vite :5173 in parallel
make dev-api         FastAPI only
make dev-frontend    Vite only — list will load empty (no backend)
make lint-api        ruff + pyright on api/
make test-api        pytest api/tests/
make test-frontend   Vitest
make build           Docker image locally
make cloud-build     Cloud Build → Artifact Registry
make deploy-api      Cloud Run deploy
make deploy-windmill Windmill app push
make deploy-app      deploy-api + deploy-windmill
```

## Auth

Every non-`/healthz` request must carry `X-Service-Secret` matching `FRONTEND_SERVICE_SECRET`. Constant-time compare in `api/src/__PYTHON_PACKAGE__/auth.py`. The secret must be identical in `.env.general` (FastAPI + Vite proxy) and Windmill workspace variable (prod).

## User identity for audit rows

`X-Windmill-User` and `X-Windmill-Username` headers carry identity from the trusted server-side context to the API. In prod, `backend/call_api.ts` reads `WM_USERNAME` — the only env var that reliably rebinds per viewer in raw_apps. **Don't use `WM_EMAIL` or `WM_TOKEN`**: both are deployer-scoped.

## Verifying your work

```
make verify        # lint-api + test-api + lint-frontend + test-frontend
```

**One command.** Run it before opening a PR and paste its output into the PR
body — the claim is not that you ran it, the claim is what it printed.

## SDLC artifacts

This repo follows the org's six-stage SDLC
([`hallo-theo/.github` → `sdlc/`](https://github.com/hallo-theo/.github/tree/main/sdlc)).

| Stage | Artifact | Here |
|---|---|---|
| 1 · Plan | `intent.md` | `intent/<slug>.md` |
| 2 · Design | `spec.md` | `spec/<slug>.md` |
| 3 · Build | `plan.md` | `plan/<slug>.md`, SHA-pinned in the PR |
| 4 · Test | feedback loop | `make verify` |
| 5 · Deploy | review findings | PR comments, governed by `REVIEW.md` |
| 6 · Maintain | incident record | `lessons.md` |

Each folder's README states what its artifact must contain. `intent/` and
`spec/` must contain **no personal data** — no tenant or owner names,
addresses, IBANs, emails or phone numbers, including in pasted text. Git
history is immutable and is copied into every clone and every agent session.

On Front-Door-born repos the admin agent maintains `plan/roadmap.md` +
`plan/tickets.json` (contract: `hallo-theo/.github` →
`sdlc/templates/roadmap.md`) — the plan for everything after the first
slice. Worker agents (`agent-build.yml`) then claim tickets from the
front-door board, build them on `front-door/tk<N>-*` branches, and stamp
`Ticket-Complete: TK-<n>` into the final PR body — the platform marks the
ticket done when that PR merges.

The single required check to merge is `gates-passed`. Agent PRs on
`front-door/*` branches additionally merge only after a `theo-pr-reviewer`
approval (armed by `arm-on-approval.yml`).

## CI/CD

PR checks: `.github/workflows/pr.yml` delegates to `hallo-theo/.github/.github/workflows/python-ts-pr.yml`. Deploy: `main.yml` delegates to `python-ts-deploy.yml`. When the shared workflows need to change, edit them in `hallo-theo/.github` once and every adopting repo picks them up on the next run.

Agent PRs (`front-door/*`) self-repair: `heal-agent-pr.yml` listens to every
push to main and to PR-gate failures, relays into a `repository_dispatch`
(the healing agent cannot run on push events — found live), then merges main
into dirty/behind agent branches and fixes red checks (`[heal]` commits,
capped at 2 since the last approval — then the supervisor or a human takes
over).

## Guardrails (enforced-only)

Rules land here via PR, one row each. A rule must name the check that enforces
it; a rule nothing enforces is a wish and goes under *Advisory* instead. A
mistake flagged twice in review stops being a review finding and becomes a row
here.

| Rule | Enforced by |
|------|-------------|
| Merge only via PR with `gates-passed` green | `sdlc-floor` ruleset |
| No personal data in `intent/` or `spec/` | PII gate in CI |
| Prompts, tool definitions and thresholds live in the declared behaviour-bearing paths and never auto-merge | `auto-merge-eligible` classifier |
| Agent-built UI (`front-door/*` PRs) styled with the athena design tokens (`docs/DESIGN.md`) | review-then-green: `arm-on-approval` merges agent PRs only on a `theo-pr-reviewer` approval, and token divergence is a blocking finding |
| Agent-built UI (`front-door/*` PRs) obeys `docs/PRODUCT.md`: declared UI language on every user-facing string, no dead controls (disabled filters / always-empty columns) | review-then-green: the org reviewer treats both as blocking findings on UI-touching PRs |
| Agent prompts (first-slice, decompose, worker workflows) keep mentioning the org contracts and never change silently — a prompt edit must re-pin `sdlc/prompt-contracts.json` in the same PR (`scripts/check_prompt_surface.py --update`) | `prompt-surface` job in `gates-passed` (shared PR workflow; fixtures: `.github/scripts/test-prompt-surface.sh`) |

### Advisory (not yet enforced — say so honestly)

- UI in **human** PRs follows `docs/DESIGN.md` too — the reviewer flags
  divergence, but nothing gates a trusted-branch merge on it yet. Graduates
  to the enforced table when the athena design lint joins `gates-passed`
  (Cloud Run stack work).

## Skills in use

Org skills come from the `builder-tools` plugin (`/plugin install
builder-tools@hallotheo`); repo-local skills live in `.claude/skills/<name>/SKILL.md`.
There is deliberately no `SKILLS.md` manifest — the directory is the manifest.

## Lessons

`tasks/lessons.md` is append-only. When something costs you an hour, it costs
the next agent a line.
