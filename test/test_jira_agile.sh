#!/usr/bin/env bash
# Unit tests for agile boards and sprints

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIRA_BIN="${SCRIPT_DIR}/../bin/jira"

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

assert_contains() {
  local desc="$1"
  local needle="$2"
  local haystack="$3"
  total=$((total + 1))
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "  ✓ $desc: PASS"
  else
    echo "  ✗ $desc: FAIL (could not find '$needle' in '$haystack')"
    failed=$((failed + 1))
  fi
}

echo "═══════════════════════════════════════════════════"
echo "  Testing Agile Boards & Sprints Management"
echo "═══════════════════════════════════════════════════"

# Direct sprint add dry-run
dry_out=$("$JIRA_BIN" sprint add 101 PROJ-456 --dry-run 2>/dev/null)
assert_contains "Sprint add dry-run endpoint" "POST /rest/agile/1.0/sprint/101/issue" "$dry_out"
assert_eq "Sprint add issue key payload" "PROJ-456" "$(echo "$dry_out" | sed '1d' | jq -r '.issues[0] // empty')"

# Agile router prefix sprint add dry-run
dry_agile=$("$JIRA_BIN" agile sprint add 202 PROJ-789 --dry-run 2>/dev/null)
assert_contains "Agile router sprint add endpoint" "POST /rest/agile/1.0/sprint/202/issue" "$dry_agile"
assert_eq "Agile router sprint add payload" "PROJ-789" "$(echo "$dry_agile" | sed '1d' | jq -r '.issues[0] // empty')"

echo
echo "Results: $((total - failed))/$total passed"
if [ $failed -gt 0 ]; then
  exit 1
fi
exit 0
