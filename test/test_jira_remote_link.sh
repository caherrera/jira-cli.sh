#!/usr/bin/env bash
# Unit tests for jira remote links and web links

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

echo "═══════════════════════════════════════════════════"
echo "  Testing Remote Web Links & GitLab MR Links"
echo "═══════════════════════════════════════════════════"

# Direct command
dry_out=$("$JIRA_BIN" link-url PROJ-123 https://gitlab.com/org/repo/-/merge_requests/45 --title "GitLab MR !45" --summary "Feature implementation" --dry-run 2>/dev/null)
assert_eq "Remote link url" "https://gitlab.com/org/repo/-/merge_requests/45" "$(echo "$dry_out" | jq -r '.object.url // empty')"
assert_eq "Remote link title" "GitLab MR !45" "$(echo "$dry_out" | jq -r '.object.title // empty')"
assert_eq "Remote link summary" "Feature implementation" "$(echo "$dry_out" | jq -r '.object.summary // empty')"

# Hierarchical command
dry_hier=$("$JIRA_BIN" issue link-url PROJ-123 https://github.com/org/repo/pull/99 --title "PR #99" --dry-run 2>/dev/null)
assert_eq "Hierarchical link url" "https://github.com/org/repo/pull/99" "$(echo "$dry_hier" | jq -r '.object.url // empty')"

# Ticket shortcut
dry_short=$("$JIRA_BIN" PROJ-123 --link-url https://confluence.org/page/123 --title "Design Spec" --dry-run 2>/dev/null)
assert_eq "Shortcut link url" "https://confluence.org/page/123" "$(echo "$dry_short" | jq -r '.object.url // empty')"

echo
echo "Results: $((total - failed))/$total passed"
if [ $failed -gt 0 ]; then
  exit 1
fi
exit 0
