#!/usr/bin/env bash
# Unit tests for flexible intent-driven command routing and HTTP methods

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIRA_BIN="${SCRIPT_DIR}/../bin/jira"

failed=0
total=0

assert_contains() {
  local desc="$1"
  local needle="$2"
  local haystack="$3"
  total=$((total + 1))
  if echo "$haystack" | grep -qi "$needle"; then
    echo "  ✓ $desc: PASS"
  else
    echo "  ✗ $desc: FAIL (expected substring '$needle')"
    echo "    Output was: $haystack"
    failed=$((failed + 1))
  fi
}

echo "═══════════════════════════════════════════════════"
echo "  Testing Flexible Intent-Driven Command Router"
echo "═══════════════════════════════════════════════════"

# Shortcut: jira PROJ-123 -m "msg"
out_comment=$("$JIRA_BIN" PROJ-123 -m "Fast comment" --dry-run 2>&1)
assert_contains "jira PROJ-123 -m 'msg' routes to comment" "Fast comment" "$out_comment"

# Shortcut: jira PROJ-123 --to-done
out_done=$("$JIRA_BIN" PROJ-123 --to-done --dry-run 2>&1)
assert_contains "jira PROJ-123 --to-done routes to transition" "PROJ-123" "$out_done"

# Shortcut: jira PROJ-123 --worklog 2h
out_wl=$("$JIRA_BIN" PROJ-123 --worklog 2h -m "Test" --dry-run 2>&1)
assert_contains "jira PROJ-123 --worklog routes to worklog" "7200" "$out_wl"

# Shortcut: jira PROJ-123 --branch
out_br=$("$JIRA_BIN" PROJ-123 --branch --summary "Test Branch" -N 2>&1)
assert_contains "jira PROJ-123 --branch routes to branch" "feature/PROJ-123-test-branch" "$out_br"

# Shortcut: jira PROJ-123 --link-url
out_link=$("$JIRA_BIN" PROJ-123 --link-url https://gitlab.com/test --title "MR" --dry-run 2>&1)
assert_contains "jira PROJ-123 --link-url routes to remote link" "https://gitlab.com/test" "$out_link"

# HTTP DELETE method support in dry run
out_del=$(JIRA_HOST="https://jira.example.com" "$JIRA_BIN" DELETE /issue/PROJ-123 --dry-run 2>&1)
assert_contains "jira DELETE /endpoint is accepted" "DRY-RUN" "$out_del"

echo
echo "Results: $((total - failed))/$total passed"
if [ $failed -gt 0 ]; then
  exit 1
fi
exit 0
