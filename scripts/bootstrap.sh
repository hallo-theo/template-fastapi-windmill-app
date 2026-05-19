#!/usr/bin/env bash
#
# bootstrap.sh — one-time init for repos cloned from this template.
#
# What it does:
#   1. Prompts for the app slug (or takes it as $1).
#   2. Derives the substitution map from the slug (display title, Python
#      package, Cloud Run service name, etc.). Org-wide defaults are
#      baked in (GCP project, region, Windmill workspace, base URL).
#   3. Search-and-replaces every __PLACEHOLDER__ token in every file.
#   4. Renames path segments containing placeholders.
#   5. Prints the gcloud commands needed for WIF + Secret Manager setup —
#      doesn't run them (template repo can't; that's a human action with
#      `gcloud auth`).
#   6. Self-deletes (this script).
#
# Run once after `gh repo create --template hallo-theo/template-fastapi-windmill-app`:
#   bash scripts/bootstrap.sh
#
# For a fully automated version (skill drives gcloud + Windmill setup too),
# use Claude Code's `/new-app` skill from the builder-tools plugin instead.

set -euo pipefail

# ── 1. Slug ────────────────────────────────────────────────────────────
if [[ -n "${1:-}" ]]; then
  SLUG="$1"
else
  default_slug="$(basename "$(pwd)")"
  read -r -p "App slug (kebab-case) [$default_slug]: " SLUG
  SLUG="${SLUG:-$default_slug}"
fi
if [[ ! "$SLUG" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo "✗ Slug must match ^[a-z][a-z0-9-]*\$ (lowercase + digits + hyphens, starting with a letter)" >&2
  exit 1
fi

# ── 2. Derivations + org defaults ─────────────────────────────────────
SLUG_SNAKE="${SLUG//-/_}"
TITLE="$(echo "$SLUG" | awk -F- '{for(i=1;i<=NF;i++){ printf "%s%s", toupper(substr($i,1,1)), substr($i,2); if (i<NF) printf " " }}')"
PYTHON_PACKAGE="${SLUG_SNAKE}_api"
CLOUD_RUN_SERVICE="${SLUG}-api"
ARTIFACT_REGISTRY_REPO="${SLUG}"
WMILL_APP_PATH="f/${SLUG_SNAKE}/app"

GCP_PROJECT="project-shepherd-494112"
GCP_PROJECT_NUMBER="757287535499"
GCP_REGION="europe-west3"
WMILL_WORKSPACE="hallotheo"
WMILL_BASE_URL="https://windmill-server-cfvpf3ocvq-ey.a.run.app"

# ── 3. Show the substitution map ─────────────────────────────────────
cat <<EOM
About to apply this substitution map:

  PROJECT_SLUG            $SLUG
  PROJECT_SLUG_SNAKE      $SLUG_SNAKE
  PROJECT_TITLE           $TITLE
  PYTHON_PACKAGE          $PYTHON_PACKAGE
  CLOUD_RUN_SERVICE       $CLOUD_RUN_SERVICE
  ARTIFACT_REGISTRY_REPO  $ARTIFACT_REGISTRY_REPO
  WMILL_APP_PATH          $WMILL_APP_PATH
  GCP_PROJECT             $GCP_PROJECT
  GCP_PROJECT_NUMBER      $GCP_PROJECT_NUMBER
  GCP_REGION              $GCP_REGION
  WMILL_WORKSPACE         $WMILL_WORKSPACE
  WMILL_BASE_URL          $WMILL_BASE_URL

EOM
read -r -p "Proceed? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }

# ── 4. Substitute every __PLACEHOLDER__ in every tracked file ────────
substitute() {
  local file="$1"
  # macOS sed needs '' after -i; GNU sed is fine with just -i. Use a portable temp file.
  python3 - "$file" <<PY
import sys, pathlib
p = pathlib.Path(sys.argv[1])
text = p.read_text(encoding='utf-8')
subs = {
    "__PROJECT_SLUG__":          "$SLUG",
    "__PROJECT_SLUG_SNAKE__":    "$SLUG_SNAKE",
    "__PROJECT_TITLE__":         "$TITLE",
    "__PYTHON_PACKAGE__":        "$PYTHON_PACKAGE",
    "__CLOUD_RUN_SERVICE__":     "$CLOUD_RUN_SERVICE",
    "__ARTIFACT_REGISTRY_REPO__":"$ARTIFACT_REGISTRY_REPO",
    "__WMILL_APP_PATH__":        "$WMILL_APP_PATH",
    "__GCP_PROJECT__":           "$GCP_PROJECT",
    "__GCP_PROJECT_NUMBER__":    "$GCP_PROJECT_NUMBER",
    "__GCP_REGION__":            "$GCP_REGION",
    "__WMILL_WORKSPACE__":       "$WMILL_WORKSPACE",
    "__WMILL_BASE_URL__":        "$WMILL_BASE_URL",
}
for k, v in subs.items():
    text = text.replace(k, v)
p.write_text(text, encoding='utf-8')
PY
}

while IFS= read -r -d '' file; do
  substitute "$file"
done < <(git ls-files -z 2>/dev/null || find . -type f -not -path './.git/*' -print0)

# ── 5a. Rename path segments containing placeholders ─────────────────
# api/src/__PYTHON_PACKAGE__/  →  api/src/<python_package>/
# app/__PROJECT_SLUG__.raw_app/ → app/<slug>.raw_app/
if [[ -d "api/src/__PYTHON_PACKAGE__" ]]; then
  mv "api/src/__PYTHON_PACKAGE__" "api/src/$PYTHON_PACKAGE"
fi
if [[ -d "app/__PROJECT_SLUG__.raw_app" ]]; then
  mv "app/__PROJECT_SLUG__.raw_app" "app/${SLUG}.raw_app"
fi

# ── 5b. Replace the template-usage README with the per-app one ───────
if [[ -f "_app_readme.md.template" ]]; then
  mv "_app_readme.md.template" "README.md"
fi

# ── 6. Print the gcloud commands the engineer still needs to run ─────
cat <<EOM

✓ Substitution complete.

Next manual steps:

  # 1. Bootstrap GCP for this repo (5 commands).
  #    Engineer needs roles/iam.workloadIdentityPoolAdmin + service-accounts.create
  #    in $GCP_PROJECT.
  PROJECT=$GCP_PROJECT
  PROJECT_NUMBER=$GCP_PROJECT_NUMBER
  REPO=$SLUG

  gcloud iam service-accounts create \${REPO}-deploy \\
    --display-name="\${REPO} — CI/CD deploy" --project=\${PROJECT}

  for role in roles/artifactregistry.writer roles/iam.serviceAccountUser roles/run.developer; do
    gcloud projects add-iam-policy-binding \${PROJECT} \\
      --member="serviceAccount:\${REPO}-deploy@\${PROJECT}.iam.gserviceaccount.com" \\
      --role="\$role"
  done

  gcloud iam workload-identity-pools providers create-oidc \${REPO} \\
    --workload-identity-pool=github-pool --location=global --project=\${PROJECT} \\
    --display-name="\${REPO}" \\
    --description="Trusts GitHub's OIDC issuer, scoped to hallo-theo/\${REPO}." \\
    --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.actor=assertion.actor,attribute.ref=assertion.ref" \\
    --attribute-condition="assertion.repository == 'hallo-theo/\${REPO}'" \\
    --issuer-uri="https://token.actions.githubusercontent.com"

  gcloud iam service-accounts add-iam-policy-binding \\
    \${REPO}-deploy@\${PROJECT}.iam.gserviceaccount.com --project=\${PROJECT} \\
    --role=roles/iam.workloadIdentityUser \\
    --member="principalSet://iam.googleapis.com/projects/\${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-pool/attribute.repository/hallo-theo/\${REPO}"

  gcloud secrets add-iam-policy-binding hallotheo-wmill-token \\
    --project=\${PROJECT} \\
    --member="serviceAccount:\${REPO}-deploy@\${PROJECT}.iam.gserviceaccount.com" \\
    --role=roles/secretmanager.secretAccessor

  # 2. Bootstrap the Cloud Run service so CI can update it.
  gcloud run deploy $CLOUD_RUN_SERVICE \\
    --image=us-docker.pkg.dev/cloudrun/container/hello \\
    --region=$GCP_REGION --project=$GCP_PROJECT \\
    --no-allow-unauthenticated --quiet

  # 3. Create Windmill workspace variables. Requires wmill CLI + the
  #    Windmill CI token from Secret Manager.
  WMILL_TOKEN=\$(gcloud secrets versions access latest \\
    --secret=hallotheo-wmill-token --project=$GCP_PROJECT)
  FRONTEND_SERVICE_SECRET=\$(openssl rand -hex 32)
  CLOUD_RUN_URL=\$(gcloud run services describe $CLOUD_RUN_SERVICE \\
    --region=$GCP_REGION --project=$GCP_PROJECT --format="value(status.url)")

  npm install -g windmill-cli
  wmill workspace add ci-local $WMILL_WORKSPACE $WMILL_BASE_URL --token "\$WMILL_TOKEN"

  wmill --workspace ci-local variable create \\
    --path "f/$SLUG_SNAKE/cloud_run_url" --value "\$CLOUD_RUN_URL"
  wmill --workspace ci-local variable create \\
    --path "f/$SLUG_SNAKE/frontend_service_secret" \\
    --value "\$FRONTEND_SERVICE_SECRET" --is-secret

  # 4. Write .env.general for local dev (use the same secret).
  printf 'FRONTEND_SERVICE_SECRET=%s\\n' "\$FRONTEND_SERVICE_SECRET" > .env.general

  # 5. Install deps + run.
  make install
  make dev

For a fully automated path that runs all of the above for you, use the
'/new-app' skill from hallotheo's builder-tools plugin in Claude Code.

EOM

# ── 7. Self-delete ───────────────────────────────────────────────────
rm -- "$0"
echo "✓ bootstrap.sh removed (one-shot). Commit the result + push."
