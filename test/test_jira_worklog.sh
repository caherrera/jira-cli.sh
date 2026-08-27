#!/usr/bin/env bash
# Unit tests for jira worklog duration parser and CLI dry-run

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIRA_BIN="${SCRIPT_DIR}/../bin/jira"
source "${SCRIPT_DIR}/../lib/jira.worklog.sh"

failed=0
total=0

assert_eq() {
  local desc="$1"
  local expected="$2"
  local actual="$3"
  total=$((total + 1))
  if [[ "$expected" == "$actual" ]]; then
    echo "  ✓ $desc: PASS"
  else
    echo "  ✗ $desc: FAIL (expected '$expected', got '$actual')"
    failed=$((failed + 1))
  fi
}

echo "═══════════════════════════════════════════════════"
echo "  Testing Worklog Duration Parser & Formatting"
echo "═══════════════════════════════════════════════════"

# Seconds parsing
assert_eq "Parse 30m" "1800" "$(parse_duration_to_seconds "30m")"
assert_eq "Parse 2h" "7200" "$(parse_duration_to_seconds "2h")"
assert_eq "Parse 2h30m" "9000" "$(parse_duration_to_seconds "2h30m")"
assert_eq "Parse 1d" "28800" "$(parse_duration_to_seconds "1d")"
assert_eq "Parse 1d 4h 30m" "45000" "$(parse_duration_to_seconds "1d 4h 30m")"
assert_eq "Parse plain number as minutes" "3600" "$(parse_duration_to_seconds "60")"

# Jira duration string formatting
assert_eq "Format 1800s to 30m" "30m" "$(format_seconds_to_jira_duration 1800)"
assert_eq "Format 7200s to 2h" "2h" "$(format_seconds_to_jira_duration 7200)"
assert_eq "Format 9000s to 2h 30m" "2h 30m" "$(format_seconds_to_jira_duration 9000)"
assert_eq "Format 45000s to 1d 4h 30m" "1d 4h 30m" "$(format_seconds_to_jira_duration 45000)"

# CLI dry run
dry_out=$("$JIRA_BIN" worklog add PROJ-100 2h30m -m "Implementing feature" --dry-run 2>/dev/null)
assert_eq "CLI dry-run payload timeSpentSeconds" "9000" "$(echo "$dry_out" | jq -r '.timeSpentSeconds // empty')"

echo
echo "Results: $((total - failed))/$total passed"
if [ $failed -gt 0 ]; then
  exit 1
fi
exit 0
