#!/bin/bash
# Create or update Jira issues with Markdown conversion support.

jira_create_usage() {
  cat <<EOF
Usage: jira create [issue_key|json_file] [options]

Create or update a Jira issue.

If [issue_key] is provided, the command will update the existing issue.
If a JSON file is provided (e.g., issue.json), properties will be read from it.
Otherwise, it will create a new issue prompting for required fields.

Options:
  -p, --project <KEY>           Set the project key (defaults to \$JIRA_PROJECT).
  -t, --type <NAME>             Set the issue type (e.g., Story, Bug). Defaults to Task.
  -s, --summary <TEXT>          Set the issue summary (title).
  -d, --description <TEXT>      Set the issue description. Use '-' to read from stdin.
      --description-file <PATH>   Path to a file containing the description.
      --adf                     Use ADF format (Jira Cloud). Auto-converts Markdown to ADF.
      --wiki                    Use Wiki Markup (Jira Server). Auto-converts Markdown to Wiki.
      --no-convert              Send description as-is without conversion.
  -e, --epic <KEY>              Link the issue to an Epic.
  -a, --assignee <NAME>         Assign the issue to a user.
  -r, --reporter <NAME>         Set the reporter of the issue.
  -P, --priority <NAME>         Set the issue priority.
  -l, --link-issue <KEY>        Create a "Relates to" link to another issue.
      --template <PATH>         Path to a custom JSON template file.
  -h, --help                    Show this help message.

Examples:
  jira create --type=Bug --summary="Fix login" --description="Login issue"
  jira create issue.json
  jira create issue.json --type=Soporte
EOF
}

jira_create_main() {
  local issue_key=""
  local issue_type=""
  local project="${JIRA_PROJECT:-}"
  local summary=""
  local description=""
  local description_file=""
  local assignee=""
  local reporter=""
  local priority=""
  local epic=""
  local link_issue=""
  local template=""
  local json_file=""
  local format_flag=""
  local max_description_length=32767

  _jira_create_parse_description() {
    local desc_input="$1"
    if [ "$desc_input" = "-" ]; then
      description=$(cat -)
    else
      description="$desc_input"
    fi
  }

  _jira_create_load_from_json_file() {
    if [ -z "$json_file" ] || [ ! -f "$json_file" ]; then
      return
    fi
    info "Loading properties from $json_file..."
    command -v jq >/dev/null 2>&1 || { error "jq is required to parse JSON files."; exit 1; }
    [ -z "$project" ]     && project=$(jq -r '.project // .fields.project.key // empty' "$json_file" 2>/dev/null)
    [ -z "$issue_type" ]  && issue_type=$(jq -r '.type // .issuetype // .fields.issuetype.name // empty' "$json_file" 2>/dev/null)
    [ -z "$summary" ]     && summary=$(jq -r '.summary // .fields.summary // empty' "$json_file" 2>/dev/null)
    [ -z "$description" ] && description=$(jq -r '.description // .fields.description // empty' "$json_file" 2>/dev/null)
    [ -z "$assignee" ]    && assignee=$(jq -r '.assignee // .fields.assignee.name // empty' "$json_file" 2>/dev/null)
    [ -z "$reporter" ]    && reporter=$(jq -r '.reporter // .fields.reporter.name // empty' "$json_file" 2>/dev/null)
    [ -z "$priority" ]    && priority=$(jq -r '.priority // .fields.priority.name // empty' "$json_file" 2>/dev/null)
    [ -z "$epic" ]        && epic=$(jq -r '.epic // .fields.customfield_10100 // empty' "$json_file" 2>/dev/null)
    [ -z "$link_issue" ]  && link_issue=$(jq -r '.link // .linkIssue // empty' "$json_file" 2>/dev/null)
  }

  while [ $# -gt 0 ]; do
    case "$1" in
      -p|--project) project="$2"; shift 2 ;;
      --project=*) project="${1#*=}"; shift ;;
      -t|--type) issue_type="$2"; shift 2 ;;
      --type=*) issue_type="${1#*=}"; shift ;;
      -s|--summary) summary="$2"; shift 2 ;;
      --summary=*) summary="${1#*=}"; shift ;;
      -d|--description) _jira_create_parse_description "$2"; shift 2 ;;
      --description=*) _jira_create_parse_description "${1#*=}"; shift ;;
      --description-file) description_file="$2"; shift 2 ;;
      --description-file=*) description_file="${1#*=}"; shift ;;
      --adf) format_flag="--adf"; shift ;;
      --wiki) format_flag="--wiki"; shift ;;
      --no-convert) format_flag="--no-convert"; shift ;;
      -e|--epic) epic="$2"; shift 2 ;;
      --epic=*) epic="${1#*=}"; shift ;;
      -a|--assignee) assignee="$2"; shift 2 ;;
      --assignee=*) assignee="${1#*=}"; shift ;;
      -r|--reporter) reporter="$2"; shift 2 ;;
      --reporter=*) reporter="${1#*=}"; shift ;;
      -P|--priority) priority="$2"; shift 2 ;;
      --priority=*) priority="${1#*=}"; shift ;;
      -l|--link-issue) link_issue="$2"; shift 2 ;;
      --link-issue=*) link_issue="${1#*=}"; shift ;;
      --template) template="$2"; shift 2 ;;
      --template=*) template="${1#*=}"; shift ;;
      -h|--help) jira_create_usage; return 0 ;;
      -*)
        error "Unknown option: $1"
        jira_create_usage
        return 1
        ;;
      *)
        if [ -f "$1" ] && [[ "$1" == *.json ]]; then
          json_file="$1"
        elif [ -z "$issue_key" ]; then
          issue_key="$1"
        else
          error "Unknown option: $1"
          jira_create_usage
          return 1
        fi
        shift
        ;;
    esac
  done

  _jira_create_load_from_json_file

  if [ -z "$issue_key" ]; then
    if [ -z "$project" ]; then
      info "Enter the Project Key:"
      read -r project
      [ -z "$project" ] && { error "Project is required."; return 1; }
    fi
    if [ -z "$issue_type" ]; then
      info "Enter the Issue Type (e.g., Story, Task, Bug) [default: Task]:"
      read -r issue_type
      [ -z "$issue_type" ] && issue_type="Task"
    fi
    if [ -z "$summary" ]; then
      info "Enter the issue summary (title):"
      read -r summary
      [ -z "$summary" ] && { error "Summary is required."; return 1; }
    fi
    if [ -z "$description" ] && [ -z "$description_file" ]; then
      info "Enter issue description (finish with Ctrl-D on a new line):"
      description=$(cat)
    fi
  fi

  local md2jira_bin="${JIRA_CLI_ROOT}/bin/md2jira"
  [[ -x "$md2jira_bin" ]] || md2jira_bin="${JIRA_CLI_ROOT}/src/md2jira.sh"
  local jira_bin="${JIRA_CLI_ROOT}/bin/jira"
  [[ -x "$jira_bin" ]] || jira_bin="${JIRA_CLI_ROOT}/src/jira.sh"

  local payload_file
  payload_file=$(mktemp)
  trap 'rm -f "$payload_file"' RETURN

  local final_description=""
  local description_json_arg=""

  if [ -n "$description_file" ]; then
    final_description="$(cat "$description_file")"
  else
    final_description="$description"
  fi

  if [ -n "$final_description" ]; then
    if [ "$format_flag" = "--no-convert" ]; then
      description_json_arg="--arg"
    elif [ "$format_flag" = "--adf" ]; then
      info "Converting Markdown to ADF format (Jira Cloud)..."
      local converted
      converted=$(echo "$final_description" | "$md2jira_bin" --adf 2>&1) || true
      [ -z "$converted" ] && { error "Failed to convert description to ADF."; return 1; }
      final_description="$converted"
      description_json_arg="--argjson"
    elif [ "$format_flag" = "--wiki" ]; then
      info "Converting Markdown to Wiki Markup (Jira Server)..."
      local converted
      converted=$(echo "$final_description" | "$md2jira_bin" --wiki 2>&1) || true
      [ -z "$converted" ] && { error "Failed to convert description to Wiki."; return 1; }
      final_description="$converted"
      description_json_arg="--arg"
    else
      if [[ "${JIRA_HOST:-}" =~ atlassian\.net ]]; then
        info "Auto-detected: ADF format (Jira Cloud)"
        local converted
        converted=$(echo "$final_description" | "$md2jira_bin" --adf 2>&1) || true
        [ -z "$converted" ] && { error "Failed to convert description to ADF."; return 1; }
        final_description="$converted"
        description_json_arg="--argjson"
      else
        info "Auto-detected: Wiki Markup format (Jira Server)"
        local converted
        converted=$(echo "$final_description" | "$md2jira_bin" --wiki 2>&1) || true
        [ -z "$converted" ] && { error "Failed to convert description to Wiki."; return 1; }
        final_description="$converted"
        description_json_arg="--arg"
      fi
    fi

    local desc_length
    if [ "$description_json_arg" = "--argjson" ]; then
      desc_length=$(echo "$final_description" | wc -c | tr -d ' ')
    else
      desc_length=${#final_description}
    fi
    if [ "$desc_length" -gt "$max_description_length" ]; then
      error "Description is too long ($desc_length characters)."
      return 1
    fi
  fi

  local is_update="false"
  [ -n "$issue_key" ] && is_update="true"

  if [ "$is_update" = "true" ]; then
    if [ -n "$final_description" ] && [ -n "$description_json_arg" ]; then
      # shellcheck disable=SC2086
      jq -n \
        --arg project "$project" --arg issue_type "$issue_type" --arg summary "$summary" \
        $description_json_arg description "$final_description" \
        --arg assignee "$assignee" --arg reporter "$reporter" --arg epic "$epic" \
        --arg priority "$priority" --arg link_issue "$link_issue" \
        '{ fields: {} }
        | if $project != "" then .fields.project = { key: $project } else . end
        | if $issue_type != "" then .fields.issuetype = { name: $issue_type } else . end
        | if $summary != "" then .fields.summary = $summary else . end
        | if $description != "" then .fields.description = $description else . end
        | if $assignee != "" then .fields.assignee = { name: $assignee } else . end
        | if $reporter != "" then .fields.reporter = { name: $reporter } else . end
        | if $epic != "" then .fields.customfield_10100 = $epic else . end
        | if $priority != "" then .fields.priority = { name: $priority } else . end
        | if $link_issue != "" then .update.issuelinks[0] = { add: { type: { name: "Relates" }, outwardIssue: { key: $link_issue } } } else . end' > "$payload_file"
    else
      jq -n \
        --arg project "$project" --arg issue_type "$issue_type" --arg summary "$summary" \
        --arg assignee "$assignee" --arg reporter "$reporter" --arg epic "$epic" \
        --arg priority "$priority" --arg link_issue "$link_issue" \
        '{ fields: {} }
        | if $project != "" then .fields.project = { key: $project } else . end
        | if $issue_type != "" then .fields.issuetype = { name: $issue_type } else . end
        | if $summary != "" then .fields.summary = $summary else . end
        | if $assignee != "" then .fields.assignee = { name: $assignee } else . end
        | if $reporter != "" then .fields.reporter = { name: $reporter } else . end
        | if $epic != "" then .fields.customfield_10100 = $epic else . end
        | if $priority != "" then .fields.priority = { name: $priority } else . end
        | if $link_issue != "" then .update.issuelinks[0] = { add: { type: { name: "Relates" }, outwardIssue: { key: $link_issue } } } else . end' > "$payload_file"
    fi
    info "Updating issue $issue_key..."
    "$jira_bin" PUT "/issue/$issue_key" --data "$payload_file"
  else
    if [ -n "$final_description" ] && [ -n "$description_json_arg" ]; then
      # shellcheck disable=SC2086
      jq -n \
        --arg project "$project" --arg issue_type "$issue_type" --arg summary "$summary" \
        $description_json_arg description "$final_description" \
        --arg assignee "$assignee" --arg reporter "$reporter" --arg epic "$epic" \
        --arg priority "$priority" --arg link_issue "$link_issue" \
        '{ fields: { project: { key: $project }, issuetype: { name: $issue_type }, summary: $summary, description: $description } }
        | if $assignee != "" then .fields.assignee = { name: $assignee } else . end
        | if $reporter != "" then .fields.reporter = { name: $reporter } else . end
        | if $epic != "" then .fields.customfield_10100 = $epic else . end
        | if $priority != "" then .fields.priority = { name: $priority } else . end
        | if $link_issue != "" then .update.issuelinks[0] = { add: { type: { name: "Relates" }, outwardIssue: { key: $link_issue } } } else . end' > "$payload_file"
    else
      jq -n \
        --arg project "$project" --arg issue_type "$issue_type" --arg summary "$summary" \
        --arg assignee "$assignee" --arg reporter "$reporter" --arg epic "$epic" \
        --arg priority "$priority" --arg link_issue "$link_issue" \
        '{ fields: { project: { key: $project }, issuetype: { name: $issue_type }, summary: $summary } }
        | if $assignee != "" then .fields.assignee = { name: $assignee } else . end
        | if $reporter != "" then .fields.reporter = { name: $reporter } else . end
        | if $epic != "" then .fields.customfield_10100 = $epic else . end
        | if $priority != "" then .fields.priority = { name: $priority } else . end
        | if $link_issue != "" then .update.issuelinks[0] = { add: { type: { name: "Relates" }, outwardIssue: { key: $link_issue } } } else . end' > "$payload_file"
    fi
    info "Creating new issue in project $project..."
    "$jira_bin" POST /issue --data "$payload_file"
  fi
}

# Return 0 when create should use the extended lib (JSON/key/interactive flags).
jira_create_should_use_extended() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      -h|--help|help)
        return 1 ;;
      --adf|--wiki|--no-convert|--description-file)
        return 0 ;;
      -p|-t|-s|-d|-e|-a|-r|-P|-l)
        return 0 ;;
      --project|--type|--summary|--description|--epic|--assignee|--reporter|--priority|--link-issue)
        return 0 ;;
      --data)
        return 1 ;;
    esac
    if [[ -f "$arg" && "$arg" == *.json ]]; then
      return 0
    fi
    if [[ "$arg" =~ ^[A-Z][A-Z0-9_]*-[0-9]+$ ]]; then
      return 0
    fi
  done
  # Plain "jira create" with no --data => interactive
  local has_data=false
  for arg in "$@"; do
    [[ "$arg" == "--data" ]] && has_data=true
  done
  [[ "$has_data" == "false" ]]
}
