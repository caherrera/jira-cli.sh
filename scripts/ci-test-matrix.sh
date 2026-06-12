#!/usr/bin/env bash
# Run inside CI matrix containers after OS packages are installed.

set -euxo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

bash scripts/ci-setup-deps.sh
curl -fsSL "https://raw.githubusercontent.com/kero-sh/shell-helpers/v2.0.5/libs/helpers.sh" -o /tmp/helpers.sh
export HELPER_SCRIPT=/tmp/helpers.sh
export JIRA_NO_UPDATE_CHECK=1

find src lib scripts -name '*.sh' ! -name '*.zsh.sh' -print0 \
  | xargs -0 shellcheck -S error -e SC1091

make check-scripts
bash test/test_help.sh
bash test/test_version_check.sh
bash test/test_self_update.sh
make test-unit
