#!/usr/bin/env bash
# Install jira-cli from a git checkout or release tree.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PREFIX="${PREFIX:-$HOME/.local}"

usage() {
  cat <<EOF
Usage: install.sh [options]

Install jira-cli to a local prefix (default: \$HOME/.local).

Options:
  --prefix PATH   Install prefix
  -h, --help      Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix) PREFIX="$2"; shift 2 ;;
    --prefix=*) PREFIX="${1#*=}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

bash "$SCRIPT_DIR/install-core.sh" --prefix "$PREFIX" --yes

echo ""
echo "Add to PATH:"
echo "  export PATH=\"${PREFIX}/bin:\$PATH\""
