#!/usr/bin/env bash
# CI dependency bootstrap: shellunittest only (helpers.sh is external; see README).

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPS_DIR="${ROOT_DIR}/.deps"
SHELLUNITTEST_REPO="https://github.com/caherrera/shellunittest.git"

mkdir -p "$DEPS_DIR"

if [[ ! -d "$DEPS_DIR/shellunittest" ]]; then
  echo "Cloning shellunittest..."
  git clone --depth 1 "$SHELLUNITTEST_REPO" "$DEPS_DIR/shellunittest"
fi

if [[ -x "$DEPS_DIR/shellunittest/bin/shut" ]]; then
  ln -sf "$DEPS_DIR/shellunittest/bin/shut" "$DEPS_DIR/shellunittest/bin/unittest"
fi

echo "Test dependencies ready (shellunittest)."
