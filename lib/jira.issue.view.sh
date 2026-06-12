#!/bin/bash
# Issue view helper: fields, full, resume output.

jira_issue_view_usage() {
  cat <<EOF
Usage: jira issue <issue_key> [options]

Description:
  Get detailed information for a Jira issue.

Options:
  --ticket <issue_key>    Issue key
  --fields <jsonpath>     Fields to display (jq expression)
  --jsonpath=<jsonpath>   Alias for --fields
  --full                  Show all available fields
  --resume | --resumen    Show a summary with key fields
  --format <format>       Output format for --resume (friendly|json)
  -h, --help              Show this help

Examples:
  jira issue ABC-123
  jira issue ABC-123 --fields '.key, .fields.summary'
  jira issue ABC-123 --full
  jira issue ABC-123 --resume
  jira issue ABC-123 --resume --format json
EOF
}

jira_issue_view_main() {
  local issue_key=""
  local jira_fields='{"key": .key,"summary": .fields.summary,"description": .fields.description,"status": .fields.status.name}'
  local resume_mode=false
  local format_output="friendly"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) jira_issue_view_usage; return 0 ;;
      --ticket) issue_key="$2"; shift 2 ;;
      --fields) jira_fields="$2"; shift 2 ;;
      --jsonpath=*) jira_fields="${1#*=}"; shift ;;
      --full) jira_fields=""; shift ;;
      --resume|--resumen) resume_mode=true; shift ;;
      --format) format_output="$2"; shift 2 ;;
      --format=*) format_output="${1#*=}"; shift ;;
      -*)
        error "Unknown option: $1"
        jira_issue_view_usage
        return 1
        ;;
      *)
        if [[ -z "$issue_key" ]]; then
          issue_key="$1"
        else
          error "Unknown argument: $1"
          return 1
        fi
        shift
        ;;
    esac
  done

  if [[ -z "$issue_key" ]]; then
    error "Issue key is required."
    jira_issue_view_usage
    return 1
  fi

  local jira_bin="${JIRA_CLI_ROOT}/bin/jira"
  [[ -x "$jira_bin" ]] || jira_bin="${JIRA_CLI_ROOT}/src/jira.sh"

  local temp
  temp=$(mktemp)
  trap 'rm -f "$temp"' RETURN

  "$jira_bin" issue "$issue_key" > "$temp"

  if [[ "$resume_mode" == "true" ]]; then
    if [[ "$format_output" != "friendly" && "$format_output" != "json" ]]; then
      error "Invalid format. Use 'friendly' or 'json'."
      return 1
    fi

    local resume_data
    resume_data=$(jq -r '
    {
        titulo: .fields.summary // "N/A",
        desc: .fields.description // "N/A",
        reporter: .fields.reporter.displayName // "N/A",
        asignee: (.fields.assignee.displayName // "Unassigned"),
        "fecha-creacion": .fields.created // "N/A",
        comentarios: (.fields.comment.comments | length // 0)
    }
    ' < "$temp")

    if [[ "$format_output" == "json" ]]; then
      echo "$resume_data" | jq .
    else
      echo "=== Issue Summary ==="
      echo "Title: $(echo "$resume_data" | jq -r '.titulo')"
      local desc_preview
      desc_preview=$(echo "$resume_data" | jq -r '.desc' | head -c 100)
      if [[ $(echo "$resume_data" | jq -r '.desc' | wc -c) -gt 100 ]]; then
        echo "Description: ${desc_preview}..."
      else
        echo "Description: $desc_preview"
      fi
      echo "Reporter: $(echo "$resume_data" | jq -r '.reporter')"
      echo "Assignee: $(echo "$resume_data" | jq -r '.asignee')"
      echo "Created: $(echo "$resume_data" | jq -r '."fecha-creacion"')"
      echo "Comments: $(echo "$resume_data" | jq -r '.comentarios')"
      echo "====================="
    fi
  else
    if [[ -n "$jira_fields" ]]; then
      jq -r "$jira_fields" < "$temp"
    else
      jq < "$temp"
    fi
  fi
}
