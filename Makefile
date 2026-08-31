.PHONY: verify install dev dev-api dev-frontend \
        test-api test-frontend lint-api lint-frontend \
        build cloud-build deploy-api deploy-windmill deploy-app

WMILL_TARGET           ?= __WMILL_WORKSPACE__
FRONTEND_WINDMILL_PATH ?= __WMILL_APP_PATH__

# `make verify` is THE feedback loop (SDLC Stage 4). One command that answers
# "is my work correct?" — the same checks CI runs, in the same order.
#
# Keep it as one target. An agent given four separate entry points has to guess
# which one means "done", and it will guess wrong. Paste this command's output
# into the PR: the claim is not that you ran it, the claim is what it printed.
verify: lint-api test-api lint-frontend test-frontend
	@echo "✓ verify passed"

install:
	uv sync
	cd app/__PROJECT_SLUG__.raw_app && npm install

# `dev` boots FastAPI on :8000 and Vite on :5173 in parallel.
# FRONTEND_SERVICE_SECRET must be set (either exported or via .env.general)
# so the Vite proxy can inject it on /api/* requests.
dev:
	@trap 'kill 0' EXIT; \
	set -a; [ -f .env.general ] && . ./.env.general; set +a; \
	uv run --package __PYTHON_PACKAGE__ uvicorn __PYTHON_PACKAGE__.main:app --reload --port 8000 & \
	cd app/__PROJECT_SLUG__.raw_app && npm run dev & \
	wait

dev-api:
	set -a; [ -f .env.general ] && . ./.env.general; set +a; \
	uv run --package __PYTHON_PACKAGE__ uvicorn __PYTHON_PACKAGE__.main:app --reload --port 8000

dev-frontend:
	cd app/__PROJECT_SLUG__.raw_app && npm run dev

test-api:
	uv run --package __PYTHON_PACKAGE__ pytest api/tests/ -v

test-frontend:
	cd app/__PROJECT_SLUG__.raw_app && npm run test

lint-api:
	uv run ruff check api/src
	uv run ruff format --check api/src
	uv run pyright api/src

# tsc mirrors what the reusable CI runs. eslint is deliberately stricter here
# than CI: the shared workflow does not run it yet, because switching it on
# there would fail existing adopters' code. Catch it locally in the meantime.
lint-frontend:
	cd app/__PROJECT_SLUG__.raw_app && npx tsc --noEmit
	cd app/__PROJECT_SLUG__.raw_app && npm run lint

build:
	docker build -f api/Dockerfile -t __PROJECT_SLUG__-api:dev .

cloud-build:
	gcloud builds submit \
		--project __GCP_PROJECT__ \
		--substitutions=COMMIT_SHA=$$(git rev-parse --short HEAD) \
		.

deploy-api:
	gcloud run deploy __CLOUD_RUN_SERVICE__ \
		--image __GCP_REGION__-docker.pkg.dev/__GCP_PROJECT__/__ARTIFACT_REGISTRY_REPO__/api:latest \
		--region __GCP_REGION__ \
		--platform managed \
		--no-allow-unauthenticated \
		--project __GCP_PROJECT__

deploy-windmill:
	cd app/__PROJECT_SLUG__.raw_app && wmill app push \
		--workspace $(WMILL_TARGET) \
		. \
		$(FRONTEND_WINDMILL_PATH)

deploy-app: deploy-api deploy-windmill
