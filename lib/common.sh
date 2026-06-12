#!/bin/bash

# Get the directory where the script is located
readonly LIB_DIR="$( cd "$( dirname $(realpath "${BASH_SOURCE[0]}" ))" && pwd )";
readonly VENDOR_DIR="$LIB_DIR/../vendor";
readonly SYSTEM_LOCAL_BIN_DIR="/usr/local/bin/jira-cli";

# Load helpers.sh with fallback locations
HELPER_FOUND=false

# 1. Check if HELPER_SCRIPT environment variable is set
if [[ -n "${HELPER_SCRIPT:-}" ]]; then
  if [[ -f "$HELPER_SCRIPT" ]]; then
    # shellcheck source=/dev/null
    source "$HELPER_SCRIPT"
    HELPER_FOUND=true  
  fi
fi

# 2. Fallback locations (in order)
if [[ "$HELPER_FOUND" == "false" ]]; then
  for helper_path in \
    "$LIB_DIR/helpers.sh" \
    "$VENDOR_DIR/helpers.sh" \
    "$SYSTEM_LOCAL_BIN_DIR/helpers.sh"; do
    if [[ -f "$helper_path" ]]; then
      # shellcheck source=/dev/null
      source "$helper_path"
      HELPER_FOUND=true
      break
    fi
  done
fi

# 3. If still not found, exit with resolution hints
if [[ "$HELPER_FOUND" == "false" ]]; then
  cat >&2 <<EOF
[CRITICAL] helpers.sh not found (external dependency; not bundled with jira-cli)

Resolve it using one of:
  1. export HELPER_SCRIPT=/path/to/helpers.sh
  2. Symlink locally: vendor/helpers.sh or lib/helpers.sh (next to this repo)
  3. After make install: \$PREFIX/vendor/helpers.sh (default ~/.local/vendor/helpers.sh)

Optional reference: https://github.com/kero-sh/shell-helpers
EOF
  exit 1
fi
