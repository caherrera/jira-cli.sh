#!/bin/bash
# Agile management functions for Jira Software REST API (/rest/agile/1.0/)
# Handles boards, active sprints, sprint backlog, and adding issues to sprints

jira_agile_main() {
    local RESOURCE="$1"
    shift || true

    local SUBCOMMAND=""
    local BOARD_ID=""
    local SPRINT_ID=""
    local ISSUE_KEY=""
    local STATE_FILTER=""
    local OUTPUT_FORMAT="json"
    local DRY_RUN_MODE=false
    local SHOW_HELP=false

    for arg in "$@"; do
        if [[ "$arg" =~ ^(-h|--help|help)$ ]]; then
            SHOW_HELP=true
            break
        fi
    done

    if [[ "$SHOW_HELP" == "true" ]]; then
        show_help_from_manual "agile" || true
        return 0
    fi

    if [[ $# -gt 0 ]]; then
        case "$1" in
            list|ls)
                SUBCOMMAND="list"; shift ;;
            current|active)
                SUBCOMMAND="current"; shift ;;
            issues)
                SUBCOMMAND="issues"; shift ;;
            add)
                SUBCOMMAND="add"; shift ;;
        esac
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --state)
                STATE_FILTER="$2"; shift 2 ;;
            --output)
                OUTPUT_FORMAT="$2"; shift 2 ;;
            --dry-run)
                DRY_RUN_MODE=true; shift ;;
            -h|--help|help)
                show_help_from_manual "agile" || true; return 0 ;;
            *)
                if [[ -z "$BOARD_ID" && "$RESOURCE" == "board" && "$1" =~ ^[0-9]+$ ]]; then
                    BOARD_ID="$1"
                elif [[ -z "$SPRINT_ID" && ("$RESOURCE" == "sprint" || "$SUBCOMMAND" == "issues" || "$SUBCOMMAND" == "add") && "$1" =~ ^[0-9]+$ ]]; then
                    SPRINT_ID="$1"
                elif [[ -z "$BOARD_ID" && "$RESOURCE" == "sprint" && "$1" =~ ^[0-9]+$ ]]; then
                    BOARD_ID="$1"
                elif [[ -z "$ISSUE_KEY" && "$1" =~ ^[A-Za-z0-9_]+-[0-9]+$ ]]; then
                    ISSUE_KEY="$1"
                fi
                shift
                ;;
        esac
    done

    local jira_bin="${JIRA_CLI_ROOT:-$DIR/..}/bin/jira"
    [[ -x "$jira_bin" ]] || jira_bin="${DIR}/jira"

    if [[ "$RESOURCE" == "board" ]]; then
        [[ -z "$SUBCOMMAND" ]] && SUBCOMMAND="list"
        case "$SUBCOMMAND" in
            list)
                local resp
                resp=$("$jira_bin" GET "/rest/agile/1.0/board" 2>/dev/null || true)
                case "$OUTPUT_FORMAT" in
                    json)
                        echo "$resp" | jq '.values // []'
                        ;;
                    table)
                        echo -e "ID\tNAME\tTYPE\tPROJECT"
                        echo "$resp" | jq -r '
                            (.values // [])[] |
                            [.id, .name, .type, (.location.projectKey // .location.displayName // "")] | @tsv
                        ' | column -t -s $'\t'
                        ;;
                    md)
                        echo "| ID | Name | Type | Project |"
                        echo "|---|---|---|---|"
                        echo "$resp" | jq -r '
                            (.values // [])[] |
                            "| " + (.id|tostring) + " | " + .name + " | " + .type + " | " + (.location.projectKey // .location.displayName // "") + " |"
                        '
                        ;;
                    *)
                        echo "$resp" | jq '.values // []'
                        ;;
                esac
                ;;
        esac
        return 0
    fi

    # Sprint resource
    [[ -z "$SUBCOMMAND" ]] && SUBCOMMAND="current"

    case "$SUBCOMMAND" in
        current|active)
            # If no board specified, find first board
            if [[ -z "$BOARD_ID" ]]; then
                local boards_resp
                boards_resp=$("$jira_bin" GET "/rest/agile/1.0/board" 2>/dev/null || true)
                BOARD_ID=$(echo "$boards_resp" | jq -r '.values[0].id // empty')
                if [[ -z "$BOARD_ID" ]]; then
                    error "No agile boards found. Specify board ID: jira sprint current <BOARD_ID>"
                    return 1
                fi
            fi

            local resp
            resp=$("$jira_bin" GET "/rest/agile/1.0/board/${BOARD_ID}/sprint?state=active" 2>/dev/null || true)
            local active_sprint
            active_sprint=$(echo "$resp" | jq '.values[0] // empty')
            if [[ -z "$active_sprint" || "$active_sprint" == "null" ]]; then
                info "No active sprint on board $BOARD_ID."
                return 0
            fi

            case "$OUTPUT_FORMAT" in
                json)
                    echo "$active_sprint" | jq .
                    ;;
                table|md)
                    echo "$active_sprint" | jq -r '
                        "Sprint: " + .name + " (ID: " + (.id|tostring) + ")\n" +
                        "State:  " + .state + "\n" +
                        "Dates:  " + (.startDate // "N/A") + " -> " + (.endDate // "N/A") + "\n" +
                        "Goal:   " + (.goal // "None")
                    '
                    ;;
                *)
                    echo "$active_sprint" | jq .
                    ;;
            esac
            ;;

        list)
            if [[ -z "$BOARD_ID" ]]; then
                local boards_resp
                boards_resp=$("$jira_bin" GET "/rest/agile/1.0/board" 2>/dev/null || true)
                BOARD_ID=$(echo "$boards_resp" | jq -r '.values[0].id // empty')
            fi
            [[ -z "$BOARD_ID" ]] && { error "Board ID required."; return 1; }

            local query=""
            [[ -n "$STATE_FILTER" ]] && query="?state=$STATE_FILTER"
            local resp
            resp=$("$jira_bin" GET "/rest/agile/1.0/board/${BOARD_ID}/sprint${query}" 2>/dev/null || true)
            case "$OUTPUT_FORMAT" in
                json)
                    echo "$resp" | jq '.values // []'
                    ;;
                table)
                    echo -e "ID\tNAME\tSTATE\tSTART_DATE\tEND_DATE"
                    echo "$resp" | jq -r '
                        (.values // [])[] |
                        [.id, .name, .state, (.startDate // ""), (.endDate // "")] | @tsv
                    ' | column -t -s $'\t'
                    ;;
                md)
                    echo "| ID | Name | State | Start | End |"
                    echo "|---|---|---|---|---|"
                    echo "$resp" | jq -r '
                        (.values // [])[] |
                        "| " + (.id|tostring) + " | " + .name + " | " + .state + " | " + (.startDate // "") + " | " + (.endDate // "") + " |"
                    '
                    ;;
                *)
                    echo "$resp" | jq '.values // []'
                    ;;
            esac
            ;;

        issues)
            if [[ -z "$SPRINT_ID" ]]; then
                error "Sprint ID is required. (e.g. jira sprint issues <SPRINT_ID>)"
                return 1
            fi
            local resp
            resp=$("$jira_bin" GET "/rest/agile/1.0/sprint/${SPRINT_ID}/issue" 2>/dev/null || true)
            case "$OUTPUT_FORMAT" in
                json)
                    echo "$resp" | jq '.issues // []'
                    ;;
                table)
                    echo -e "KEY\tTYPE\tSTATUS\tPRIORITY\tASSIGNEE\tSUMMARY"
                    echo "$resp" | jq -r '
                        (.issues // [])[] |
                        [
                            .key,
                            (.fields.issuetype.name // ""),
                            (.fields.status.name // ""),
                            (.fields.priority.name // ""),
                            (.fields.assignee.displayName // .fields.assignee.name // "Unassigned"),
                            (.fields.summary // "")
                        ] | @tsv
                    ' | column -t -s $'\t'
                    ;;
                md)
                    echo "| Key | Type | Status | Priority | Assignee | Summary |"
                    echo "|---|---|---|---|---|---|"
                    echo "$resp" | jq -r '
                        (.issues // [])[] |
                        "| " + .key + " | " + (.fields.issuetype.name // "") + " | " + (.fields.status.name // "") + " | " + (.fields.priority.name // "") + " | " + (.fields.assignee.displayName // .fields.assignee.name // "Unassigned") + " | " + (.fields.summary // "") + " |"
                    '
                    ;;
                *)
                    echo "$resp" | jq '.issues // []'
                    ;;
            esac
            ;;

        add)
            if [[ -z "$SPRINT_ID" || -z "$ISSUE_KEY" ]]; then
                error "Sprint ID and Issue key are required. (e.g. jira sprint add <SPRINT_ID> <ISSUE_KEY>)"
                return 1
            fi
            local payload_file
            payload_file=$(mktemp)
            trap 'rm -f "$payload_file"' RETURN
            jq -n --arg issue "$ISSUE_KEY" '{issues: [$issue]}' > "$payload_file"

            if [[ "$DRY_RUN_MODE" == "true" ]]; then
                echo "[DRY-RUN] POST /rest/agile/1.0/sprint/${SPRINT_ID}/issue"
                cat "$payload_file" | jq .
                return 0
            fi

            info "Adding $ISSUE_KEY to sprint $SPRINT_ID..."
            "$jira_bin" POST "/rest/agile/1.0/sprint/${SPRINT_ID}/issue" --data "$payload_file"
            success "Issue $ISSUE_KEY added to sprint $SPRINT_ID."
            ;;
    esac
}
