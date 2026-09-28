#!/usr/bin/env bash
# Fixture tests for tickets-contract.jq — run manually or from any agent
# session before editing the contract: ./github/scripts/test-tickets-contract.sh
set -euo pipefail
cd "$(dirname "$0")"

pass=0; fail=0
expect() { # name expected(0|1) json
  local name=$1 expected=$2 json=$3 rc=0
  jq -e -f tickets-contract.jq >/dev/null 2>&1 <<<"$json" || rc=1
  if [ "$rc" = "$expected" ]; then
    echo "ok   $name"; pass=$((pass+1))
  else
    echo "FAIL $name (expected rc=$expected, got rc=$rc)"; fail=$((fail+1))
  fi
}

T1='{"id":"TK-1","title":"t","description":"d","acceptance_criteria":["a"],"blocked_by":[],"area":"api","wave":1}'
T2='{"id":"TK-2","title":"t","description":"d","acceptance_criteria":["a"],"blocked_by":["TK-1"],"area":"app","wave":2}'

expect "valid 2-wave file"            0 "[$T1,$T2]"
expect "empty array is valid"         0 "[]"
expect "forward-wave blocked_by"      1 '[{"id":"TK-1","title":"t","description":"d","acceptance_criteria":["a"],"blocked_by":["TK-2"],"area":"api","wave":1},{"id":"TK-2","title":"t","description":"d","acceptance_criteria":["a"],"blocked_by":[],"area":"app","wave":2}]'
expect "same-wave blocked_by"         1 '[{"id":"TK-1","title":"t","description":"d","acceptance_criteria":["a"],"blocked_by":[],"area":"api","wave":1},{"id":"TK-2","title":"t","description":"d","acceptance_criteria":["a"],"blocked_by":["TK-1"],"area":"app","wave":1}]'
expect "dangling blocked_by"          1 '[{"id":"TK-1","title":"t","description":"d","acceptance_criteria":["a"],"blocked_by":["TK-9"],"area":"api","wave":2}]'
expect "empty acceptance_criteria"    1 '[{"id":"TK-1","title":"t","description":"d","acceptance_criteria":[],"blocked_by":[],"area":"api","wave":1}]'
expect "duplicate ids"                1 "[$T1,$T1]"
expect "bad id shape"                 1 '[{"id":"T-1","title":"t","description":"d","acceptance_criteria":["a"],"blocked_by":[],"area":"api","wave":1}]'
expect "13 tickets over the cap"      1 "$(python3 - <<'PY'
import json
print(json.dumps([{"id": f"TK-{i}", "title": "t", "description": "d",
  "acceptance_criteria": ["a"], "blocked_by": [], "area": "api", "wave": 1}
  for i in range(1, 14)]))
PY
)"

echo "----"
echo "$pass passed, $fail failed"
exit "$([ "$fail" = 0 ] && echo 0 || echo 1)"
