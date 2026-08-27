#!/bin/bash
# Issue editing functions for jira CLI
# Handles atomic field updates, labels, and components management for existing Jira issues

jira_issue_edit_main() {
    local ISSUE_KEY=""
    local SUMMARY=""
    local DESCRIPTION=""
    local DESCRIPTION_FILE=""
    local PRIORITY=""
    local ASSIGNEE=""
    local REPORTER=""
    local EPIC=""
    local ADD_LABELS=()
    local REMOVE_LABELS=()
    local ADD_COMPONENTS=()
    local REMOVE_COMPONENTS=()
    local CUSTOM_FIELDS=()
    local DRY_RUN_MODE=false
    local SHOW_HELP=false

    for arg in "$@"; do
        if [[ "$arg" =~ ^(-h|--help|help)$ ]]; then
            SHOW_HELP=true
            break
        fi
    done

    if [[ "$SHOW_HELP" == "true" ]]; then
        show_help_from_manual "edit" || true
        return 0
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--summary)
                SUMMARY="$2"; shift 2 ;;
            --summary=*)
                SUMMARY="${1#*=}"; shift ;;
            -d|--description)
                DESCRIPTION="$2"; shift 2 ;;
            --description=*)
                DESCRIPTION="${1#*=}"; shift ;;
            --description-file)
                DESCRIPTION_FILE="$2"; shift 2 ;;
            --description-file=*)
                DESCRIPTION_FILE="${1#*=}"; shift ;;
            -P|--priority)
                PRIORITY="$2"; shift 2 ;;
            --priority=*)
                PRIORITY="${1#*=}"; shift ;;
            -a|--assignee)
                ASSIGNEE="$2"; shift 2 ;;
            --assignee=*)
                ASSIGNEE="${1#*=}"; shift ;;
            -r|--reporter)
                REPORTER="$2"; shift 2 ;;
            --reporter=*)
                REPORTER="${1#*=}"; shift ;;
            -e|--epic)
                EPIC="$2"; shift 2 ;;
            --epic=*)
                EPIC="${1#*=}"; shift ;;
            --add-label|--add-labels)
                IFS=',' read -ra arr <<< "$2"
                for l in "${arr[@]}"; do ADD_LABELS+=("$(echo "$l" | sed 's/^ *//;s/ *$//')"); done
                shift 2 ;;
            --remove-label|--remove-labels)
                IFS=',' read -ra arr <<< "$2"
                for l in "${arr[@]}"; do REMOVE_LABELS+=("$(echo "$l" | sed 's/^ *//;s/ *$//')"); done
                shift 2 ;;
            --add-component|--add-components)
                IFS=',' read -ra arr <<< "$2"
                for c in "${arr[@]}"; do ADD_COMPONENTS+=("$(echo "$c" | sed 's/^ *//;s/ *$//')"); done
                shift 2 ;;
            --remove-component|--remove-components)
                IFS=',' read -ra arr <<< "$2"
                for c in "${arr[@]}"; do REMOVE_COMPONENTS+=("$(echo "$c" | sed 's/^ *//;s/ *$//')"); done
                shift 2 ;;
            -f|--field)
                CUSTOM_FIELDS+=("$2"); shift 2 ;;
            --dry-run)
                DRY_RUN_MODE=true; shift ;;
            -h|--help|help)
                show_help_from_manual "edit" || true; return 0 ;;
            *)
                if [[ -z "$ISSUE_KEY" && "$1" =~ ^[A-Za-z0-9_]+-[0-9]+$ ]]; then
                    ISSUE_KEY="$1"
                elif [[ -z "$ISSUE_KEY" && ! "$1" =~ ^- ]]; then
                    ISSUE_KEY="$1"
                else
                    error "Unknown argument: $1"
                    return 1
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$ISSUE_KEY" ]]; then
        error "Issue key is required. (e.g. jira edit PROJ-123 --summary \"New Title\")"
        show_help_from_manual "edit" || true
        return 1
    fi

    local jira_bin="${JIRA_CLI_ROOT:-$DIR/..}/bin/jira"
    [[ -x "$jira_bin" ]] || jira_bin="${DIR}/jira"
    local md2jira_bin="${JIRA_CLI_ROOT:-$DIR/..}/bin/md2jira"
    [[ -x "$md2jira_bin" ]] || md2jira_bin="${DIR}/md2jira"

    # Handle description file or stdin
    if [[ -n "$DESCRIPTION_FILE" && -f "$DESCRIPTION_FILE" ]]; then
        DESCRIPTION=$(cat "$DESCRIPTION_FILE")
    elif [[ "$DESCRIPTION" == "-" ]]; then
        if [[ ! -t 0 ]]; then
            DESCRIPTION=$(cat)
        fi
    fi

    # Build payload with jq
    local payload_file
    payload_file=$(mktemp)
    trap 'rm -f "$payload_file"' RETURN
    echo '{"fields":{},"update":{}}' > "$payload_file"

    if [[ -n "$SUMMARY" ]]; then
        jq --arg s "$SUMMARY" '.fields.summary = $s' "$payload_file" > "${payload_file}.tmp" && mv "${payload_file}.tmp" "$payload_file"
    fi

    if [[ -n "$PRIORITY" ]]; then
        jq --arg p "$PRIORITY" '.fields.priority = {name: $p}' "$payload_file" > "${payload_file}.tmp" && mv "${payload_file}.tmp" "$payload_file"
    fi

    if [[ -n "$EPIC" ]]; then
        jq --arg e "$EPIC" '.fields.customfield_10100 = $e' "$payload_file" > "${payload_file}.tmp" && mv "${payload_file}.tmp" "$payload_file"
    fi

    if [[ -n "$ASSIGNEE" ]]; then
        if [[ "$ASSIGNEE" == "none" || "$ASSIGNEE" == "null" ]]; then
            jq '.fields.assignee = null' "$payload_file" > "${payload_file}.tmp" && mv "${payload_file}.tmp" "$payload_file"
        elif [[ "$ASSIGNEE" == "me" ]]; then
            local myself_resp
            myself_resp=$("$jira_bin" profile 2>/dev/null || true)
            local my_id
            my_id=$(echo "$myself_resp" | jq -r '.accountId // .name // empty')
            if [[ -n "$my_id" ]]; then
                if [[ "${JIRA_API_VERSION:-3}" == "3" ]]; then
                    jq --arg id "$my_id" '.fields.assignee = {accountId: $id}' "$payload_file" > "${payload_file}.tmp" && mv "${payload_file}.tmp" "$payload_file"
                else
                    jq --arg name "$my_id" '.fields.assignee = {name: $name}' "$payload_file" > "${payload_file}.tmp" && mv "${payload_file}.tmp" "$payload_file"
                fi
            fi
        else
            if [[ "${JIRA_API_VERSION:-3}" == "3" ]]; then
                # Search accountId for email/user
                local user_resp
                user_resp=$("$jira_bin" user search "$ASSIGNEE" 2>/dev/null || true)
                local found_id
                found_id=$(echo "$user_resp" | jq -r 'if type == "array" and length > 0 then .[0].accountId else empty end')
                if [[ -n "$found_id" ]]; then
                    jq --arg id "$found_id" '.fields.assignee = {accountId: $id}' "$payload_file" > "${payload_file}.tmp" && mv "${payload_file}.tmp" "$payload_file"
                else
                    jq --arg id "$ASSIGNEE" '.fields.assignee = {accountId: $id}' "$payload_file" > "${payload_file}.tmp" && mv "${payload_file}.tmp" "$payload_file"
                fi
            else
                jq --arg a "$ASSIGNEE" '.fields.assignee = {name: $a}' "$payload_file" > "${payload_file}.tmp" && mv "${payload_file}.tmp" "$payload_file"
            fi
        fi
    fi

    if [[ -n "$DESCRIPTION" ]]; then
        if [[ "${JIRA_API_VERSION:-3}" == "3" ]]; then
            local adf_body
            adf_body=$(jira_text_to_adf "$DESCRIPTION")
            jq --argjson desc "$adf_body" '.fields.description = $desc' "$payload_file" > "${payload_file}.tmp" && mv "${payload_file}.tmp" "$payload_file"
        else
            local wiki_desc
            wiki_desc=$(markdown_to_jira "$DESCRIPTION" 2>/dev/null || printf '%s' "$DESCRIPTION")
            jq --arg desc "$wiki_desc" '.fields.description = $desc' "$payload_file" > "${payload_file}.tmp" && mv "${payload_file}.tmp" "$payload_file"
        fi
    fi

    # Labels (update array)
    for l in "${ADD_LABELS[@]}"; do
        [[ -z "$l" ]] && continue
        jq --arg l "$l" '.update.labels = ((.update.labels // []) + [{add: $l}])' "$payload_file" > "${payload_file}.tmp" && mv "${payload_file}.tmp" "$payload_file"
    done
    for l in "${REMOVE_LABELS[@]}"; do
        [[ -z "$l" ]] && continue
        jq --arg l "$l" '.update.labels = ((.update.labels // []) + [{remove: $l}])' "$payload_file" > "${payload_file}.tmp" && mv "${payload_file}.tmp" "$payload_file"
    done

    # Components (update array)
    for c in "${ADD_COMPONENTS[@]}"; do
        [[ -z "$c" ]] && continue
        jq --arg c "$c" '.update.components = ((.update.components // []) + [{add: {name: $c}}])' "$payload_file" > "${payload_file}.tmp" && mv "${payload_file}.tmp" "$payload_file"
    done
    for c in "${REMOVE_COMPONENTS[@]}"; do
        [[ -z "$c" ]] && continue
        jq --arg c "$c" '.update.components = ((.update.components // []) + [{remove: {name: $c}}])' "$payload_file" > "${payload_file}.tmp" && mv "${payload_file}.tmp" "$payload_file"
    done

    # Custom fields
    for field in "${CUSTOM_FIELDS[@]}"; do
        if [[ "$field" =~ ^([^=]+)=(.*)$ ]]; then
            local k="${BASH_REMATCH[1]}"
            local v="${BASH_REMATCH[2]}"
            jq --arg k "$k" --arg v "$v" '.fields[$k] = $v' "$payload_file" > "${payload_file}.tmp" && mv "${payload_file}.tmp" "$payload_file"
        fi
    done

    # Clean empty objects
    jq '
        (if .fields == {} then del(.fields) else . end) |
        (if .update == {} then del(.update) else . end)
    ' "$payload_file" > "${payload_file}.tmp" && mv "${payload_file}.tmp" "$payload_file"

    if [[ "$DRY_RUN_MODE" == "true" ]]; then
        echo "[DRY-RUN] PUT /issue/${ISSUE_KEY}" >&2
        cat "$payload_file" | jq .
        return 0
    fi

    info "Updating issue $ISSUE_KEY..."
    local resp
    resp=$("$jira_bin" PUT "/issue/${ISSUE_KEY}" --data "$payload_file")
    success "Issue $ISSUE_KEY updated successfully."
}
