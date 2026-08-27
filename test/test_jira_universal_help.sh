#!/usr/bin/env bash
# Test universal contextual help across all subcommands and argument positions

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIRA_BIN="${SCRIPT_DIR}/../bin/jira"

failed=0
total=0

assert_help_success() {
  local desc="$1"
  shift
  total=$((total + 1))
  local output
  if output=$("$JIRA_BIN" "$@" 2>&1); then
    if echo "$output" | grep -qiE '(usage|sintaxis|opciones|options|descripción|description|ejemplos|examples)'; then
      echo "  ✓ $desc: PASS"
      return 0
    fi
  fi
  echo "  ✗ $desc: FAIL (args: $*)"
  echo "    Output was: $output"
  failed=$((failed + 1))
  return 1
}

echo "═══════════════════════════════════════════════════"
echo "  Testing Universal Contextual Help (-h / --help)"
echo "═══════════════════════════════════════════════════"

# Root help
assert_help_success "jira -h" -h
assert_help_success "jira --help" --help
assert_help_success "jira help" help

# Issue help
assert_help_success "jira issue -h" issue -h
assert_help_success "jira issue --help" issue --help
assert_help_success "jira help issue" help issue
assert_help_success "jira issue ABC-123 -h" issue ABC-123 -h
assert_help_success "jira ABC-123 --help" ABC-123 --help

# Branch help
assert_help_success "jira branch -h" branch -h
assert_help_success "jira branch --help" branch --help
assert_help_success "jira issue branch -h" issue branch -h
assert_help_success "jira issue branch create --help" issue branch create --help
assert_help_success "jira help branch" help branch

# Comment help
assert_help_success "jira comment -h" comment -h
assert_help_success "jira comment --help" comment --help
assert_help_success "jira issue comment -h" issue comment -h
assert_help_success "jira issue comment --help" issue comment --help
assert_help_success "jira help comment" help comment

# Transition / Done / Redo help
assert_help_success "jira transition -h" transition -h
assert_help_success "jira transition done --help" transition done --help
assert_help_success "jira issue transition -h" issue transition -h
assert_help_success "jira done -h" done -h
assert_help_success "jira redo --help" redo --help

# Attach help
assert_help_success "jira attach -h" attach -h
assert_help_success "jira attach --help" attach --help
assert_help_success "jira issue attach -h" issue attach -h

# Link / Link-url help
assert_help_success "jira link -h" link -h
assert_help_success "jira link --help" link --help
assert_help_success "jira link-url -h" link-url -h
assert_help_success "jira issue link -h" issue link -h
assert_help_success "jira issue link-url --help" issue link-url --help

# Worklog help
assert_help_success "jira worklog -h" worklog -h
assert_help_success "jira worklog --help" worklog --help
assert_help_success "jira issue worklog -h" issue worklog -h

# Edit help
assert_help_success "jira edit -h" edit -h
assert_help_success "jira issue edit --help" issue edit --help

# Agile (board / sprint) help
assert_help_success "jira board -h" board -h
assert_help_success "jira sprint -h" sprint -h
assert_help_success "jira sprint --help" sprint --help

# Existing resources
assert_help_success "jira project -h" project -h
assert_help_success "jira search --help" search --help
assert_help_success "jira user -h" user -h
assert_help_success "jira profile --help" profile --help
assert_help_success "jira api -h" api -h

echo
echo "Results: $((total - failed))/$total passed"
if [ $failed -gt 0 ]; then
  exit 1
fi
exit 0
