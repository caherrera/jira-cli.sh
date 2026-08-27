#!/usr/bin/env bash
# Unit tests for jira branch functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIRA_BIN="${SCRIPT_DIR}/../bin/jira"
source "${SCRIPT_DIR}/../lib/jira.branch.sh"

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
echo "  Testing Branch Name Generation & Prefix Inference"
echo "═══════════════════════════════════════════════════"

# Prefix determination
assert_eq "Feature for Story" "feature" "$(determine_branch_prefix "Story" "Medium")"
assert_eq "Hotfix for critical Bug" "hotfix" "$(determine_branch_prefix "Bug" "Highest")"
assert_eq "Bugfix for normal Bug" "bugfix" "$(determine_branch_prefix "Bug" "Low")"
assert_eq "Task for Task" "task" "$(determine_branch_prefix "Task" "Medium")"
assert_eq "Chore for Maintenance" "chore" "$(determine_branch_prefix "Mantenimiento" "Low")"
assert_eq "Spike for Discovery" "spike" "$(determine_branch_prefix "Spike" "Medium")"

# Sanitization
assert_eq "Sanitize accents" "atencion-al-cliente-and-mas" "$(generate_branch_slug "¡Atención al cliente & más!")"
assert_eq "Sanitize special characters" "fix-issue-with-login-api-v20" "$(generate_branch_slug "Fix issue with login / API [v2.0]")"

# Build branch name
assert_eq "Build branch name standard" "feature/PROJ-123-new-login-flow" "$(build_branch_name "feature" "PROJ-123" "New login flow")"
assert_eq "Build branch name with truncation" "bugfix/PROJ-456-very-long-summary-that-needs-to-be-truncated" "$(build_branch_name "bugfix" "PROJ-456" "Very long summary that needs to be truncated properly so it fits under limit")"

# Dry run from CLI
dry_out=$("$JIRA_BIN" branch PROJ-999 --summary "Payment integration" --prefix feature -N 2>/dev/null)
assert_eq "CLI dry-run branch generation" "feature/PROJ-999-payment-integration" "$dry_out"

# Hierarchical CLI dry run
dry_hier=$("$JIRA_BIN" issue branch create PROJ-888 --summary "Fix database index" --prefix hotfix -N 2>/dev/null)
assert_eq "CLI hierarchical dry-run" "hotfix/PROJ-888-fix-database-index" "$dry_hier"

echo
echo "Results: $((total - failed))/$total passed"
if [ $failed -gt 0 ]; then
  exit 1
fi
exit 0
