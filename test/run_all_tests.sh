#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SHELLUNITTEST_ROOT="${SHELLUNITTEST_DIR:-${PROJECT_ROOT}/.deps/shellunittest}"

echo "═══════════════════════════════════════════════════"
echo "  Running All Tests for jira-cli.sh"
echo "═══════════════════════════════════════════════════"
echo

# Prefer shellunittest CLI when available (*.test.sh convention)
UNITTEST=""
for candidate in \
  "${SHELLUNITTEST_ROOT}/bin/unittest" \
  "${SHELLUNITTEST_ROOT}/bin/shut" \
  "${SHELLUNITTEST_ROOT}/src/unittest-cli.sh"; do
  if [[ -x "$candidate" ]] || [[ -f "$candidate" ]]; then
    UNITTEST="$candidate"
    break
  fi
done

exit_code=0

if [[ -n "$UNITTEST" ]]; then
  for test_file in "$SCRIPT_DIR"/test_*.sh; do
    [[ -f "$test_file" ]] || continue
    base=$(basename "$test_file")
    # test_help.sh: Makefile; test_helpers.sh: external kero-sh/shell-helpers (not tested here)
    [[ "$base" == "test_help.sh" || "$base" == "test_helpers.sh" ]] && continue
    echo "Running: $base"
    bash "$UNITTEST" "$test_file" "$@" || exit_code=$?
  done
else
  echo "WARN: shellunittest CLI not found; running tests directly"
  for test_file in "$SCRIPT_DIR"/test_*.sh; do
    [[ -f "$test_file" ]] || continue
    base=$(basename "$test_file")
    [[ "$base" == "test_help.sh" || "$base" == "test_helpers.sh" ]] && continue
    echo "Running: $base"
    bash "$test_file" "$@" || exit_code=$?
  done
fi

echo
echo "═══════════════════════════════════════════════════"
if [ $exit_code -eq 0 ]; then
  echo "  ✓ All tests passed!"
else
  echo "  ✗ Some tests failed"
fi
echo "═══════════════════════════════════════════════════"

exit $exit_code
