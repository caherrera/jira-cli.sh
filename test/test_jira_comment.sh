#!/usr/bin/env bash
# Unit tests for jira comment functionality and ADF conversion

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
echo "  Testing Jira Comments & ADF Conversion"
echo "═══════════════════════════════════════════════════"

# Dry-run comment add with ADF wrapper
JIRA_API_VERSION=3
export JIRA_API_VERSION
dry_out=$("$JIRA_BIN" comment add PROJ-123 "Plain comment text" --dry-run 2>/dev/null)
assert_eq "Comment type is doc" "doc" "$(echo "$dry_out" | jq -r '.body.type // empty')"
assert_eq "Comment text extracted" "Plain comment text" "$(echo "$dry_out" | jq -r '.body.content[0].content[0].text // empty')"

# Dry-run comment edit
dry_edit=$("$JIRA_BIN" comment edit PROJ-123 10050 -m "Updated comment" --dry-run 2>/dev/null)
assert_eq "Edit comment doc type" "doc" "$(echo "$dry_edit" | jq -r '.body.type // empty')"
assert_eq "Edit comment text" "Updated comment" "$(echo "$dry_edit" | jq -r '.body.content[0].content[0].text // empty')"

# Hierarchical command variant
dry_hier=$("$JIRA_BIN" issue comment PROJ-123 -m "Hierarchical comment" --dry-run 2>/dev/null)
assert_eq "Hierarchical comment text" "Hierarchical comment" "$(echo "$dry_hier" | jq -r '.body.content[0].content[0].text // empty')"

# Direct ticket flag shortcut
dry_shortcut=$("$JIRA_BIN" PROJ-123 -m "Shortcut comment" --dry-run 2>/dev/null)
assert_eq "Shortcut comment text" "Shortcut comment" "$(echo "$dry_shortcut" | jq -r '.body.content[0].content[0].text // empty')"

echo
echo "Results: $((total - failed))/$total passed"
if [ $failed -gt 0 ]; then
  exit 1
fi
exit 0
