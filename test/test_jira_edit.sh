#!/usr/bin/env bash
# Unit tests for jira issue editing, labels, and components

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
echo "  Testing Issue Editing & Labels/Components"
echo "═══════════════════════════════════════════════════"

JIRA_API_VERSION=3
export JIRA_API_VERSION

# Edit summary and priority
dry_out=$("$JIRA_BIN" edit PROJ-100 --summary "Updated Summary" --priority High --dry-run 2>/dev/null)
assert_eq "Updated summary" "Updated Summary" "$(echo "$dry_out" | jq -r '.fields.summary // empty')"
assert_eq "Updated priority" "High" "$(echo "$dry_out" | jq -r '.fields.priority.name // empty')"

# Atomic label addition & removal
dry_labels=$("$JIRA_BIN" issue edit PROJ-100 --add-label backend,v2 --remove-label legacy --dry-run 2>/dev/null)
assert_eq "Add label 1" "backend" "$(echo "$dry_labels" | jq -r '.update.labels[0].add // empty')"
assert_eq "Add label 2" "v2" "$(echo "$dry_labels" | jq -r '.update.labels[1].add // empty')"
assert_eq "Remove label" "legacy" "$(echo "$dry_labels" | jq -r '.update.labels[2].remove // empty')"

# Atomic component addition & removal
dry_comps=$("$JIRA_BIN" edit PROJ-100 --add-component API --remove-component OldCore --dry-run 2>/dev/null)
assert_eq "Add component" "API" "$(echo "$dry_comps" | jq -r '.update.components[0].add.name // empty')"
assert_eq "Remove component" "OldCore" "$(echo "$dry_comps" | jq -r '.update.components[1].remove.name // empty')"

# Custom field
dry_cf=$("$JIRA_BIN" edit PROJ-100 --field customfield_10014=EPIC-500 --dry-run 2>/dev/null)
assert_eq "Custom field assignment" "EPIC-500" "$(echo "$dry_cf" | jq -r '.fields.customfield_10014 // empty')"

echo
echo "Results: $((total - failed))/$total passed"
if [ $failed -gt 0 ]; then
  exit 1
fi
exit 0
