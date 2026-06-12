#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/.."

source "${PROJECT_ROOT}/lib/common.sh"
source "${PROJECT_ROOT}/lib/jira.version.sh"

JIRA_CLI_ROOT="$PROJECT_ROOT"

pass=0
fail=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "PASS: $desc"
    pass=$((pass + 1))
  else
    echo "FAIL: $desc (expected '$expected', got '$actual')"
    fail=$((fail + 1))
  fi
}

assert_eq "read version" "0.1.0" "$(jira_read_version)"
assert_eq "semver equal" "0" "$(jira_semver_compare "0.1.0" "0.1.0")"
assert_eq "semver lt" "-1" "$(jira_semver_compare "0.1.0" "0.2.0")"
assert_eq "semver gt" "1" "$(jira_semver_compare "0.2.0" "0.1.0")"

output=$("${PROJECT_ROOT}/src/jira.sh" --version 2>/dev/null)
assert_eq "cli --version" "jira-cli 0.1.0" "$output"

echo
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
