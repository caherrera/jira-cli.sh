#!/usr/bin/env bash
# Unit tests for jira attachments management

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
echo "  Testing Jira Attachments & File Upload"
echo "═══════════════════════════════════════════════════"

# Create a temporary file for attachment tests
tmp_file=$(mktemp)
echo "Sample attachment content" > "$tmp_file"
trap 'rm -f "$tmp_file"' EXIT

# Direct command attach dry-run
dry_out=$("$JIRA_BIN" attach PROJ-123 "$tmp_file" --dry-run 2>/dev/null)
assert_contains "Attach upload dry-run endpoint" "/rest/api/3/issue/PROJ-123/attachments" "$dry_out"
assert_contains "Attach upload security header" "X-Atlassian-Token: no-check" "$dry_out"
assert_contains "Attach upload file included" "$tmp_file" "$dry_out"

# Hierarchical command attach dry-run
dry_hier=$("$JIRA_BIN" issue attach PROJ-123 "$tmp_file" --dry-run 2>/dev/null)
assert_contains "Hierarchical attach dry-run" "/rest/api/3/issue/PROJ-123/attachments" "$dry_hier"

# Error handling: missing file
err_out=$("$JIRA_BIN" attach PROJ-123 /nonexistent/file/path.png 2>&1 || true)
assert_contains "Error on missing file" "File does not exist" "$err_out"

echo
echo "Results: $((total - failed))/$total passed"
if [ $failed -gt 0 ]; then
  exit 1
fi
exit 0
