#!/bin/bash
# Issue view helper: rich console view, fields, full, resume output.

jira_issue_view_usage() {
  show_help_from_manual "issue" || true
}

jira_issue_view_main() {
  local issue_key=""
  local jira_fields=""
  local resume_mode=false
  local rich_view=true
  local format_output="friendly"
  local SHOW_HELP=false

  for arg in "$@"; do
    if [[ "$arg" =~ ^(-h|--help|help)$ ]]; then
      SHOW_HELP=true
      break
    fi
  done

  if [[ "$SHOW_HELP" == "true" ]]; then
    jira_issue_view_usage
    return 0
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help|help)
        jira_issue_view_usage; return 0 ;;
      --ticket)
        issue_key="$2"; shift 2 ;;
      --fields)
        jira_fields="$2"; rich_view=false; shift 2 ;;
      --jsonpath=*)
        jira_fields="${1#*=}"; rich_view=false; shift ;;
      --full|--json)
        jira_fields=""; rich_view=false; format_output="json"; shift ;;
      --resume|--resumen)
        resume_mode=true; shift ;;
      --format)
        format_output="$2"; shift 2 ;;
      --format=*)
        format_output="${1#*=}"; shift ;;
      *)
        if [[ -z "$issue_key" && "$1" =~ ^[A-Za-z0-9_]+-[0-9]+$ ]]; then
          issue_key="$1"
        elif [[ -z "$issue_key" && ! "$1" =~ ^- ]]; then
          issue_key="$1"
        fi
        shift
        ;;
    esac
  done

  if [[ -z "$issue_key" ]]; then
    error "Issue key is required. (e.g. jira issue view PROJ-123)"
    return 1
  fi

  local jira_bin="${JIRA_CLI_ROOT:-$DIR/..}/bin/jira"
  [[ -x "$jira_bin" ]] || jira_bin="${DIR}/jira"

  local temp
  temp=$(mktemp)
  trap 'rm -f "$temp"' RETURN

  local raw_data
  raw_data=$("$jira_bin" GET "/issue/${issue_key}" 2>/dev/null || true)
  printf '%s' "$raw_data" > "$temp"

  if ! jq -e '.key' "$temp" >/dev/null 2>&1; then
    error "Could not retrieve issue $issue_key"
    printf '%s\n' "$raw_data" >&2
    return 1
  fi

  # If user specifically asked for JSON / fields
  if [[ "$rich_view" == "false" && "$resume_mode" == "false" ]]; then
    if [[ -n "$jira_fields" ]]; then
      jq -r "$jira_fields" "$temp"
    else
      jq . "$temp"
    fi
    return 0
  fi

  # Extract fields
  local key summary issue_type status_name status_cat priority assignee reporter created updated labels components
  key=$(jq -r '.key // ""' "$temp")
  summary=$(jq -r '.fields.summary // "N/A"' "$temp")
  issue_type=$(jq -r '.fields.issuetype.name // "N/A"' "$temp")
  status_name=$(jq -r '.fields.status.name // "N/A"' "$temp")
  status_cat=$(jq -r '.fields.status.statusCategory.name // "N/A"' "$temp")
  priority=$(jq -r '.fields.priority.name // "None"' "$temp")
  assignee=$(jq -r '.fields.assignee.displayName // .fields.assignee.name // "Unassigned"' "$temp")
  reporter=$(jq -r '.fields.reporter.displayName // .fields.reporter.name // "Unknown"' "$temp")
  created=$(jq -r '.fields.created // "N/A"' "$temp")
  updated=$(jq -r '.fields.updated // "N/A"' "$temp")
  labels=$(jq -r '(.fields.labels // []) | join(", ")' "$temp")
  components=$(jq -r '[(.fields.components // [])[].name] | join(", ")' "$temp")

  # Description extraction (from ADF or string)
  local desc
  local desc_type
  desc_type=$(jq -r '.fields.description | type' "$temp")
  if [[ "$desc_type" == "object" ]]; then
    desc=$(jq -r '[.fields.description | .. | .text? // empty] | join(" ")' "$temp")
  else
    desc=$(jq -r '.fields.description // ""' "$temp")
  fi
  [[ -z "$desc" || "$desc" == "null" ]] && desc="(No description provided)"

  # Color helpers
  local c_cyan="\033[1;36m"
  local c_green="\033[1;32m"
  local c_yellow="\033[1;33m"
  local c_blue="\033[1;34m"
  local c_magenta="\033[1;35m"
  local c_bold="\033[1m"
  local c_dim="\033[2m"
  local c_reset="\033[0m"

  local status_color="$c_blue"
  case "$status_cat" in
    "Done") status_color="$c_green" ;;
    "To Do") status_color="$c_dim" ;;
    "In Progress") status_color="$c_yellow" ;;
  esac

  if [[ "$format_output" == "json" ]]; then
    jq -r '
    {
      key: .key,
      summary: .fields.summary,
      type: .fields.issuetype.name,
      status: .fields.status.name,
      statusCategory: .fields.status.statusCategory.name,
      priority: .fields.priority.name,
      assignee: (.fields.assignee.displayName // "Unassigned"),
      reporter: (.fields.reporter.displayName // "Unknown"),
      created: .fields.created,
      updated: .fields.updated,
      labels: .fields.labels,
      components: [.fields.components[]?.name],
      commentsCount: (.fields.comment.comments | length // 0)
    }' "$temp" | jq .
    return 0
  fi

  # Render terminal layout
  echo -e "${c_cyan}${c_bold}${key}${c_reset}  ${c_bold}${summary}${c_reset}"
  echo -e "${c_dim}─────────────────────────────────────────────────────────────${c_reset}"
  echo -e "  ${c_dim}Status:${c_reset}     ${status_color}[${status_name}]${c_reset} (${status_cat})    ${c_dim}Type:${c_reset}     ${c_magenta}${issue_type}${c_reset}"
  echo -e "  ${c_dim}Priority:${c_reset}   ${priority}                  ${c_dim}Assignee:${c_reset} ${c_bold}${assignee}${c_reset}"
  echo -e "  ${c_dim}Reporter:${c_reset}   ${reporter}               ${c_dim}Updated:${c_reset}  ${updated}"
  [[ -n "$labels" ]] && echo -e "  ${c_dim}Labels:${c_reset}     ${labels}"
  [[ -n "$components" ]] && echo -e "  ${c_dim}Components:${c_reset} ${components}"
  echo -e "${c_dim}─────────────────────────────────────────────────────────────${c_reset}"
  echo -e "${c_bold}Description:${c_reset}"
  echo -e "$desc"
  echo ""

  # Subtasks
  local subtasks_count
  subtasks_count=$(jq -r '(.fields.subtasks // []) | length' "$temp")
  if [[ "$subtasks_count" -gt 0 ]]; then
    echo -e "${c_bold}Subtasks (${subtasks_count}):${c_reset}"
    jq -r '(.fields.subtasks // [])[] | "  - " + .key + " [" + .fields.status.name + "] " + .fields.summary' "$temp"
    echo ""
  fi

  # Issue links
  local links_count
  links_count=$(jq -r '(.fields.issuelinks // []) | length' "$temp")
  if [[ "$links_count" -gt 0 ]]; then
    echo -e "${c_bold}Linked Issues (${links_count}):${c_reset}"
    jq -r '(.fields.issuelinks // [])[] |
      if .outwardIssue then
        "  - " + .type.outward + " -> " + .outwardIssue.key + " [" + .outwardIssue.fields.status.name + "] " + .outwardIssue.fields.summary
      elif .inwardIssue then
        "  - " + .type.inward + " <- " + .inwardIssue.key + " [" + .inwardIssue.fields.status.name + "] " + .inwardIssue.fields.summary
      else empty end
    ' "$temp"
    echo ""
  fi

  # Comments preview
  local comments_count
  comments_count=$(jq -r '(.fields.comment.comments // []) | length' "$temp")
  if [[ "$comments_count" -gt 0 ]]; then
    echo -e "${c_bold}Recent Comments (${comments_count}):${c_reset}"
    jq -r '(.fields.comment.comments // [])[-2:] | .[] |
      "  " + "\u001b[1m" + (.author.displayName // "Unknown") + "\u001b[0m (" + .created + "):\n" +
      (
        if (.body | type) == "object" then
          "    " + ([.. | .text? // empty] | join(" ") | gsub("[\r\n]"; " "))
        else
          "    " + ((.body // "") | gsub("[\r\n]"; " "))
        end
      ) + "\n"
    ' "$temp"
  fi
  echo -e "${c_dim}View in browser: ${JIRA_HOST%/}/browse/${key}${c_reset}"
}
