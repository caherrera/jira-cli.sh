#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/.."

source "${PROJECT_ROOT}/lib/common.sh"
source "${PROJECT_ROOT}/lib/jira.version.sh"

JIRA_CLI_ROOT="$PROJECT_ROOT"

pass=0
fail=0

check() {
  local desc="$1"
  shift
  if "$@"; then
    echo "PASS: $desc"
    pass=$((pass + 1))
  else
    echo "FAIL: $desc"
    fail=$((fail + 1))
  fi
}

check "self-update help exits 0" bash "${PROJECT_ROOT}/src/jira.sh" self-update --help
check "update alias help exits 0" bash "${PROJECT_ROOT}/src/jira.sh" update --help
check "install-core exists" test -f "${PROJECT_ROOT}/scripts/install-core.sh"

echo
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
