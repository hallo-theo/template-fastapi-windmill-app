#!/usr/bin/env bash
# Fixture tests for scripts/check_prompt_surface.py — run manually or from any
# agent session before editing the checker or the manifest format:
#   .github/scripts/test-prompt-surface.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/scripts" "$TMP/sdlc" "$TMP/wf"
cp "$ROOT/scripts/check_prompt_surface.py" "$TMP/scripts/"

pass=0; fail=0
expect() { # name expected_rc
  local name=$1 expected=$2 rc=0
  (cd "$TMP" && python3 scripts/check_prompt_surface.py >/dev/null 2>&1) || rc=1
  if [ "$rc" = "$expected" ]; then
    echo "ok   $name"; pass=$((pass+1))
  else
    echo "FAIL $name (expected rc=$expected, got rc=$rc)"; fail=$((fail+1))
  fi
}

manifest() { # marker_pattern
  cat > "$TMP/sdlc/prompt-contracts.json" <<JSON
{"files":[{"path":"wf/prompt.yml","sha256_16":"PLACEHOLDER","must_mention":[{"contract":"product standard","pattern":"$1"}]}]}
JSON
}

echo "the prompt mentions docs/PRODUCT.md here" > "$TMP/wf/prompt.yml"
manifest "docs/PRODUCT\\\\.md"
(cd "$TMP" && python3 scripts/check_prompt_surface.py --update >/dev/null)
expect "clean surface passes" 0

echo "an edit without re-pinning" >> "$TMP/wf/prompt.yml"
expect "changed prompt without manifest update fails" 1

(cd "$TMP" && python3 scripts/check_prompt_surface.py --update >/dev/null)
expect "after --update it passes again" 0

echo "the contract is gone from this prompt" > "$TMP/wf/prompt.yml"
(cd "$TMP" && python3 scripts/check_prompt_surface.py --update >/dev/null 2>&1) || true
expect "dropped contract marker fails even with fresh hash" 1

rm "$TMP/wf/prompt.yml"
expect "listed file missing from repo fails" 1

echo "$pass ok, $fail failed"
[ "$fail" = 0 ]
