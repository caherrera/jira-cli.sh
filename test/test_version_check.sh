#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/.."

source "${PROJECT_ROOT}/lib/common.sh"
source "${PROJECT_ROOT}/lib/jira.version.sh"

JIRA_CLI_ROOT="$PROJECT_ROOT"
EXPECTED_VERSION="$(tr -d '[:space:]' < "${PROJECT_ROOT}/VERSION")"

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

assert_eq "read version" "$EXPECTED_VERSION" "$(jira_read_version)"
assert_eq "semver equal" "0" "$(jira_semver_compare "$EXPECTED_VERSION" "$EXPECTED_VERSION")"
assert_eq "semver lt" "-1" "$(jira_semver_compare "$EXPECTED_VERSION" "99.99.99")"
assert_eq "semver gt" "1" "$(jira_semver_compare "99.99.99" "$EXPECTED_VERSION")"

output=$("${PROJECT_ROOT}/src/jira.sh" --version 2>/dev/null)
assert_eq "cli --version" "jira-cli ${EXPECTED_VERSION}" "$output"

echo
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
