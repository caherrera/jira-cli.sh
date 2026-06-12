#!/bin/bash
# Version detection, passive update check, and self-update

JIRA_CLI_GITHUB_REPO="${JIRA_CLI_GITHUB_REPO:-caherrera/jira-cli.sh}"
JIRA_VERSION_CACHE_FILE="${JIRA_VERSION_CACHE_FILE:-${HOME}/.cache/jira-cli/version-check}"
JIRA_VERSION_CACHE_TTL_SECONDS=86400

jira_cli_root_dir() {
  if [[ -n "${JIRA_CLI_ROOT:-}" ]]; then
    echo "$JIRA_CLI_ROOT"
    return
  fi
  if [[ -n "${DIR:-}" ]]; then
    echo "$(cd "$DIR/.." && pwd)"
    return
  fi
  echo "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
}

jira_read_installed_version() {
  local root prefix version_file
  root="$(jira_cli_root_dir)"

  if [[ -n "${PREFIX:-}" && -f "${PREFIX}/VERSION" ]]; then
    cat "${PREFIX}/VERSION"
    return 0
  fi

  for version_file in "$root/VERSION" "$(dirname "$(command -v jira 2>/dev/null || true)")/../VERSION"; do
    if [[ -f "$version_file" ]]; then
      cat "$version_file"
      return 0
    fi
  done

  echo "dev"
}

jira_semver_strip_v() {
  local v="${1#v}"
  echo "$v"
}

# Returns 0 if remote > local
jira_semver_gt() {
  local remote="${1#v}"
  local local_v="${2#v}"
  local r_major r_minor r_patch l_major l_minor l_patch

  IFS='.' read -r r_major r_minor r_patch <<< "$remote"
  IFS='.' read -r l_major l_minor l_patch <<< "$local_v"

  r_major=${r_major:-0}; r_minor=${r_minor:-0}; r_patch=${r_patch:-0}
  l_major=${l_major:-0}; l_minor=${l_minor:-0}; l_patch=${l_patch:-0}

  if (( r_major > l_major )); then return 0; fi
  if (( r_major < l_major )); then return 1; fi
  if (( r_minor > l_minor )); then return 0; fi
  if (( r_minor < l_minor )); then return 1; fi
  if (( r_patch > l_patch )); then return 0; fi
  return 1
}

jira_fetch_latest_release_tag() {
  local response tag
  response=$(curl --max-time 5 -fsSL \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${JIRA_CLI_GITHUB_REPO}/releases/latest" 2>/dev/null) || return 1
  tag=$(echo "$response" | jq -r '.tag_name // empty')
  [[ -n "$tag" && "$tag" != "null" ]] || return 1
  echo "$tag"
}

jira_fetch_release_tag() {
  local version="$1"
  if [[ -z "$version" || "$version" == "latest" ]]; then
    jira_fetch_latest_release_tag
  else
    [[ "$version" == v* ]] || version="v${version}"
    echo "$version"
  fi
}

jira_version_cache_valid() {
  [[ -f "$JIRA_VERSION_CACHE_FILE" ]] || return 1
  local now cached_ts
  now=$(date +%s)
  cached_ts=$(head -n1 "$JIRA_VERSION_CACHE_FILE" 2>/dev/null || echo 0)
  (( now - cached_ts < JIRA_VERSION_CACHE_TTL_SECONDS ))
}

jira_version_cache_write() {
  local remote_tag="$1"
  mkdir -p "$(dirname "$JIRA_VERSION_CACHE_FILE")"
  {
    date +%s
    echo "$remote_tag"
  } > "$JIRA_VERSION_CACHE_FILE"
}

jira_version_cache_read() {
  sed -n '2p' "$JIRA_VERSION_CACHE_FILE" 2>/dev/null
}

jira_print_version() {
  local version
  version="$(jira_read_installed_version)"
  echo "jira-cli ${version}"
}

jira_read_version() {
  jira_read_installed_version
}

# Compare semver strings; prints -1, 0, or 1.
jira_semver_compare() {
  local a="${1#v}" b="${2#v}"
  if jira_semver_gt "v$a" "v$b"; then
    echo 1
  elif jira_semver_gt "v$b" "v$a"; then
    echo -1
  else
    echo 0
  fi
}

jira_self_update_main() {
  jira_self_update "$@"
}

jira_passive_version_check() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      --help|-h|help|--shell|self-update|update|--version|-V) return 0 ;;
    esac
  done
  jira_maybe_notify_update
}

jira_maybe_notify_update() {
  [[ "${CI:-}" == "true" || "${JIRA_NO_UPDATE_CHECK:-}" == "1" ]] && return 0
  [[ "${JIRA_SKIP_VERSION_CHECK:-}" == "1" ]] && return 0

  local local_v remote_v
  local_v="$(jira_read_installed_version)"
  [[ "$local_v" == "dev" ]] && return 0

  if jira_version_cache_valid; then
    remote_v="$(jira_version_cache_read)"
  else
    remote_v="$(jira_fetch_latest_release_tag 2>/dev/null || true)"
    [[ -n "$remote_v" ]] && jira_version_cache_write "$remote_v"
  fi

  [[ -z "$remote_v" ]] && return 0

  if jira_semver_gt "$remote_v" "$local_v"; then
    echo "A new version of jira-cli is available: ${remote_v} (installed: ${local_v}). Run: jira self-update" >&2
  fi
}

jira_detect_install_prefix() {
  local jira_path prefix
  jira_path="$(command -v jira 2>/dev/null || true)"
  if [[ -z "$jira_path" ]]; then
    echo ""
    return 1
  fi
  if command -v realpath >/dev/null 2>&1; then
    jira_path="$(realpath "$jira_path")"
  fi
  prefix="$(cd "$(dirname "$jira_path")/.." && pwd)"
  echo "$prefix"
}

jira_self_update_usage() {
  cat <<EOF
Usage: jira self-update [options]

Update jira-cli to the latest GitHub release (or a pinned version).

Options:
  --check              Compare local vs remote; exit 0 if up to date, 1 if update available
  --version <tag>      Pin to a specific release tag (e.g. v0.1.0)
  --yes                Non-interactive install
  --prefix <path>      Install prefix (default: detected from jira binary)
  -h, --help           Show this help

Alias: jira update
EOF
}

jira_self_update() {
  local check_only=false
  local yes_flag=false
  local version_pin=""
  local prefix=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --check) check_only=true; shift ;;
      --yes) yes_flag=true; shift ;;
      --version) version_pin="$2"; shift 2 ;;
      --version=*) version_pin="${1#*=}"; shift ;;
      --prefix) prefix="$2"; shift 2 ;;
      --prefix=*) prefix="${1#*=}"; shift ;;
      -h|--help) jira_self_update_usage; exit 0 ;;
      *) error "Unknown option: $1"; jira_self_update_usage; exit 1 ;;
    esac
  done

  local local_v remote_v root
  local_v="$(jira_read_installed_version)"
  remote_v="$(jira_fetch_release_tag "${version_pin:-latest}")" || {
    error "Could not fetch release information from GitHub"
    exit 1
  }

  if [[ "$check_only" == "true" ]]; then
    if jira_semver_gt "$remote_v" "$local_v"; then
      echo "Update available: ${remote_v} (installed: ${local_v})"
      exit 1
    fi
    echo "Already up to date (${local_v})"
    exit 0
  fi

  if ! jira_semver_gt "$remote_v" "$local_v" && [[ "$local_v" != "dev" ]]; then
    if [[ "$(jira_semver_strip_v "$remote_v")" == "$(jira_semver_strip_v "$local_v")" ]]; then
      echo "Already up to date (${local_v})"
      exit 0
    fi
  fi

  if [[ -z "$prefix" ]]; then
    prefix="$(jira_detect_install_prefix || true)"
  fi

  if [[ -z "$prefix" ]]; then
    error "Could not detect install prefix. Use: jira self-update --prefix \$HOME/.local"
    exit 1
  fi

  if [[ "$local_v" == "dev" && ! -f "${prefix}/VERSION" ]]; then
    error "Dev install detected (no VERSION in ${prefix}). Use: git pull && make install PREFIX=${prefix}"
    exit 1
  fi

  if [[ "$yes_flag" != "true" ]]; then
    if [[ ! -t 0 ]]; then
      error "Non-interactive shell requires --yes for jira self-update"
      exit 1
    fi
    read -r -p "Update jira-cli ${local_v} -> ${remote_v} in ${prefix}? [y/N] " confirm
    case "$confirm" in
      y|Y|yes|YES) ;;
      *) echo "Cancelled."; exit 0 ;;
    esac
  fi

  if [[ ! -w "$prefix" ]]; then
    error "Prefix ${prefix} is not writable. Try: PREFIX=${prefix} jira self-update --yes"
    exit 1
  fi

  root="$(jira_cli_root_dir)"
  local install_core="${root}/scripts/install-core.sh"
  if [[ ! -f "$install_core" ]]; then
    error "install-core.sh not found at ${install_core}"
    exit 1
  fi

  bash "$install_core" --prefix "$prefix" --version "$remote_v" --yes
  rm -f "$JIRA_VERSION_CACHE_FILE"
  jira_print_version
}
