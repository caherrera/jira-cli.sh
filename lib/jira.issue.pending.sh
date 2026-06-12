#!/bin/bash
# Pending issues JQL helper (assignee=currentUser, not Done).

jira_issue_pending_usage() {
  cat <<EOF
Usage: jira issue pending [options]

Description:
  List issues assigned to the current user that are not in Done status.

Options:
  -h, --help    Show this help

Examples:
  jira issue pending
EOF
}

jira_issue_pending_main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) jira_issue_pending_usage; exit 0 ;;
      *) error "Unknown option: $1"; jira_issue_pending_usage; exit 1 ;;
    esac
  done

  local jira_bin="${JIRA_CLI_ROOT}/bin/jira"
  [[ -x "$jira_bin" ]] || jira_bin="${JIRA_CLI_ROOT}/src/jira.sh"
  "$jira_bin" GET "/search?jql=assignee=currentUser()%20AND%20statusCategory!=Done&fields=key,summary,status"
}
