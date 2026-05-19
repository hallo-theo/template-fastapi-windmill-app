# template-fastapi-windmill-app

GitHub template repo for new hallo theo apps that pair a **FastAPI backend
on Cloud Run** with a **TypeScript Vite + React frontend hosted as a
Windmill raw_app**. Same shape as
[`object-details`](https://github.com/hallo-theo/object-details) and
[`project-shepherd`](https://github.com/hallo-theo/project-shepherd).

> For the **automated path** (Claude Code drives everything — one
> question, GCP and Windmill set up for you), use the
> [`/new-app` skill](https://github.com/hallo-theo/hallotheo-claude-plugins/tree/main/plugins/builder-tools/skills/new-app)
> from the `builder-tools` plugin. This template repo is the **manual
> path** for engineers without Claude Code, or who want to see what
> gets created before running gcloud.

## How to use

### 1. Create your repo from this template

```bash
gh repo create hallo-theo/<your-slug> \
  --template hallo-theo/template-fastapi-windmill-app \
  --private --clone
cd <your-slug>
```

Or via the GitHub UI: **New repository → Use this template → hallo-theo/template-fastapi-windmill-app**.

### 2. Run the bootstrap script

```bash
bash scripts/bootstrap.sh
```

The script will:
- Ask for your app slug (or take it as `$1`).
- Apply the substitution map: derives display title, Python package, Cloud Run service name, etc. Org-wide defaults are baked in (GCP project, region, Windmill workspace, base URL).
- Search-and-replace every `__PLACEHOLDER__` token in every file.
- Rename `api/src/__PYTHON_PACKAGE__/` and `app/__PROJECT_SLUG__.raw_app/` to the actual names.
- Replace this template-usage README with a per-app README (`_app_readme.md.template` → `README.md`).
- Print the gcloud + wmill commands needed for WIF + Secret Manager + Cloud Run + Windmill workspace setup. Doesn't run them — that needs your `gcloud auth`. Copy-paste them.
- Self-delete.

### 3. Run the gcloud + wmill setup that the script printed

About 5 minutes of `gcloud` + `wmill` commands. Prerequisites:
- `gcloud` authenticated with `roles/iam.workloadIdentityPoolAdmin` + `roles/iam.serviceAccountAdmin` + `roles/secretmanager.secretAccessor` in `project-shepherd-494112`
- `gh` authenticated with hallo-theo org access
- `wmill` CLI installed (`npm install -g windmill-cli`)
- `openssl` available
- The org-shared `hallotheo-wmill-token` secret exists in Secret Manager (one-time org bootstrap; if not, see `hallo-theo/.github`'s README)

### 4. Commit + push

```bash
git add -A
git commit -m "Initialize from template"
git push
```

Open a PR (e.g. a README tweak) to validate the PR check workflow. Merge → `main.yml` auto-deploys to Cloud Run + Windmill.

## What's in the box

| Path | What |
|------|------|
| `api/` | FastAPI on uv workspace. Just `/healthz` + auth middleware — no CRUD, no DB. |
| `api/src/__PYTHON_PACKAGE__/auth.py` | The shared-secret middleware (reusable verbatim) |
| `app/__PROJECT_SLUG__.raw_app/` | Vite + React + TS raw_app. Hello-world reading `backend.whoami()`. |
| `app/__PROJECT_SLUG__.raw_app/backend/{call_api,whoami}.ts` | Windmill runnables (WIF + service-secret + audit headers) |
| `.github/workflows/{pr,main}.yml` | ~10-line callers into `hallo-theo/.github`'s reusable workflows |
| `Makefile` | `make install / dev / test / deploy-*` |
| `api/Dockerfile` | Multi-stage uv build |
| `scripts/bootstrap.sh` | One-shot template init (self-deletes) |
| `_app_readme.md.template` | The per-app README that replaces this one after bootstrap |

## What's deliberately NOT in the box

- **No Postgres or DB scaffolding.** Add `psycopg`, `db.py`, migrations, `docker-compose.yml` when needed. Reference: [`hallo-theo/object-details`](https://github.com/hallo-theo/object-details).
- **No CRUD endpoints, audit log, exports, PDF generation.** Object-details patterns; copy in when needed.
- **No terraform.** Add per-app once infra needs are clear.

## Manual path vs `/new-app` skill — when to use which

| | `gh repo create --template` + bootstrap.sh | `/new-app` skill in Claude Code |
|---|---|---|
| Available without Claude Code | ✅ | ❌ |
| Discoverable via GitHub UI "Use template" | ✅ | ❌ |
| Auto-runs the gcloud + wmill setup | ❌ (prints commands) | ✅ |
| Auto-bootstraps the Cloud Run service | ❌ | ✅ |
| Auto-creates Windmill workspace variables | ❌ | ✅ |
| Auto-writes .env.general locally | ❌ | ✅ |
| Time to working repo | ~10–15 min | ~5 min |

Both get you to the same end state.

## Updating the template

When hallo-theo conventions change (new workflow input, secret naming change, new file always needed), this template should be updated **in lockstep** with the parallel `stacks/fastapi-windmill/files/` in the `new-app` skill. Keep both copies in sync.
