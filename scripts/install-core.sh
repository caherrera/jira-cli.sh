#!/usr/bin/env bash
# Core install logic for jira-cli (used by make install and jira self-update).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PREFIX="${PREFIX:-$HOME/.local}"
VERSION_PIN=""
YES=false
SHELL_HELPERS_REPO="kero-sh/shell-helpers"

usage() {
  cat <<EOF
Usage: install-core.sh [options]

Options:
  --prefix PATH     Install prefix (default: \$HOME/.local)
  --version TAG     Release tag to record in VERSION (default: repo VERSION file)
  --yes             Non-interactive
  -h, --help        Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix) PREFIX="$2"; shift 2 ;;
    --prefix=*) PREFIX="${1#*=}"; shift ;;
    --version) VERSION_PIN="$2"; shift 2 ;;
    --version=*) VERSION_PIN="${1#*=}"; shift ;;
    --yes) YES=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

resolve_helpers_tag() {
  if [[ -n "${HELPERS_VERSION:-}" ]]; then
    echo "$HELPERS_VERSION"
    return 0
  fi
  local tag
  tag="$(curl -fsSL "https://api.github.com/repos/${SHELL_HELPERS_REPO}/releases/latest" \
    | jq -r '.tag_name // empty')"
  if [[ -z "$tag" || "$tag" == "null" ]]; then
    echo "ERROR: Failed to resolve latest shell-helpers release (GitHub API)." >&2
    echo "Pin a tag with HELPERS_VERSION (e.g. v2.0.5) or check network access." >&2
    return 1
  fi
  echo "$tag"
}

install_helpers() {
  local tag url dest="$PREFIX/vendor/helpers.sh"
  tag="$(resolve_helpers_tag)" || exit 1
  url="https://raw.githubusercontent.com/${SHELL_HELPERS_REPO}/${tag}/libs/helpers.sh"
  echo "Downloading helpers.sh (${tag})..."
  if ! curl -fsSL "$url" -o "$dest"; then
    echo "ERROR: Failed to download helpers.sh from ${url}" >&2
    echo "Pin a tag with HELPERS_VERSION (e.g. v2.0.5) or check network access." >&2
    exit 1
  fi
}

mkdir -p "$PREFIX/bin" "$PREFIX/src" "$PREFIX/lib" "$PREFIX/vendor"

echo "Installing to ${PREFIX}..."
cp -r "$ROOT_DIR/bin/"* "$PREFIX/bin/"
chmod +x "$PREFIX/bin/"*
cp "$ROOT_DIR/src/"*.sh "$PREFIX/src/"
chmod +x "$PREFIX/src/"*.sh
for lib_script in "$ROOT_DIR/lib/"*.sh; do
  [[ -f "$lib_script" ]] || continue
  [[ "$(basename "$lib_script")" == "helpers.sh" ]] && continue
  cp "$lib_script" "$PREFIX/lib/"
done

install_helpers

if [[ -n "$VERSION_PIN" ]]; then
  echo "${VERSION_PIN#v}" > "$PREFIX/VERSION"
elif [[ -f "$ROOT_DIR/VERSION" ]]; then
  cp "$ROOT_DIR/VERSION" "$PREFIX/VERSION"
fi

echo "jira-cli installed to ${PREFIX}"
