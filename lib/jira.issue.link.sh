#!/bin/bash
# Create links between Jira issues.

jira_issue_link_usage() {
  cat <<EOF
Usage: jira issue link <inward_issue> <outward_issue> [options]

Description:
  Create a link between two Jira issues.

Options:
  --type <type>   Link type (default: Relates)
  -h, --help      Show this help

Examples:
  jira issue link ABC-123 ABC-456
  jira issue link ABC-123 ABC-456 --type Blocks
EOF
}

jira_issue_link_main() {
  local inward="" outward="" link_type="Relates"

  if [[ $# -ge 2 && "$1" != -* && "$2" != -* ]]; then
    inward="$1"
    outward="$2"
    shift 2
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) jira_issue_link_usage; exit 0 ;;
      --type) link_type="$2"; shift 2 ;;
      --type=*) link_type="${1#*=}"; shift ;;
      *)
        if [[ -z "$inward" ]]; then
          inward="$1"
        elif [[ -z "$outward" ]]; then
          outward="$1"
        else
          error "Unknown option: $1"
          jira_issue_link_usage
          exit 1
        fi
        shift
        ;;
    esac
  done

  if [[ -z "$inward" || -z "$outward" ]]; then
    error "Both inward and outward issue keys are required."
    jira_issue_link_usage
    exit 1
  fi

  local payload
  payload=$(jq -n \
    --arg type "$link_type" \
    --arg inward "$inward" \
    --arg outward "$outward" \
    '{
      type: { name: $type },
      inwardIssue: { key: $inward },
      outwardIssue: { key: $outward }
    }')

  local jira_bin="${JIRA_CLI_ROOT}/bin/jira"
  [[ -x "$jira_bin" ]] || jira_bin="${JIRA_CLI_ROOT}/src/jira.sh"
  "$jira_bin" POST /issueLink --data "$payload"
}
