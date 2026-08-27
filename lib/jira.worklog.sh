#!/bin/bash
# Worklog and time tracking management for jira CLI
# Handles parsing human-readable duration strings (2h30m, 1d 4h, 45m) and recording worklogs

parse_duration_to_seconds() {
    local input="$1"
    local total_seconds=0
    # Clean input and convert to lowercase
    input=$(echo "$input" | tr '[:upper:]' '[:lower:]')

    # Extract days (1d = 8 hours = 28800 seconds in standard Jira workday)
    if [[ "$input" =~ ([0-9]+)[[:space:]]*d ]]; then
        local days="${BASH_REMATCH[1]}"
        total_seconds=$((total_seconds + days * 28800))
    fi

    # Extract hours (1h = 3600 seconds)
    if [[ "$input" =~ ([0-9]+)[[:space:]]*h ]]; then
        local hours="${BASH_REMATCH[1]}"
        total_seconds=$((total_seconds + hours * 3600))
    fi

    # Extract minutes (1m = 60 seconds)
    if [[ "$input" =~ ([0-9]+)[[:space:]]*m ]]; then
        local minutes="${BASH_REMATCH[1]}"
        total_seconds=$((total_seconds + minutes * 60))
    fi

    # If pure number without unit, assume minutes
    if [[ "$total_seconds" -eq 0 && "$input" =~ ^[0-9]+$ ]]; then
        total_seconds=$((input * 60))
    fi

    echo "$total_seconds"
}

format_seconds_to_jira_duration() {
    local seconds="$1"
    local days=$((seconds / 28800))
    local rem=$((seconds % 28800))
    local hours=$((rem / 3600))
    local minutes=$(((rem % 3600) / 60))

    local out=""
    [[ $days -gt 0 ]] && out="${days}d "
    [[ $hours -gt 0 ]] && out="${out}${hours}h "
    [[ $minutes -gt 0 ]] && out="${out}${minutes}m"
    out=$(echo "$out" | sed 's/ *$//')
    [[ -z "$out" ]] && out="1m"
    echo "$out"
}

jira_worklog_main() {
    local SUBCOMMAND=""
    local ISSUE_KEY=""
    local DURATION_STR=""
    local WORKLOG_ID=""
    local COMMENT=""
    local STARTED_AT=""
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
        show_help_from_manual "worklog" || true
        return 0
    fi

    if [[ $# -gt 0 ]]; then
        case "$1" in
            add|create|new|log)
                SUBCOMMAND="add"; shift ;;
            list|ls)
                SUBCOMMAND="list"; shift ;;
            delete|rm)
                SUBCOMMAND="delete"; shift ;;
        esac
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -m|--message|--comment)
                COMMENT="$2"; shift 2 ;;
            --started)
                STARTED_AT="$2"; shift 2 ;;
            --output)
                OUTPUT_FORMAT="$2"; shift 2 ;;
            --dry-run)
                DRY_RUN_MODE=true; shift ;;
            -h|--help|help)
                show_help_from_manual "worklog" || true; return 0 ;;
            *)
                if [[ -z "$ISSUE_KEY" && "$1" =~ ^[A-Za-z0-9_]+-[0-9]+$ ]]; then
                    ISSUE_KEY="$1"
                elif [[ -z "$WORKLOG_ID" && "$SUBCOMMAND" == "delete" && "$1" =~ ^[0-9]+$ ]]; then
                    WORKLOG_ID="$1"
                elif [[ -z "$DURATION_STR" && "$1" =~ [0-9]+[dhms] ]]; then
                    DURATION_STR="$1"
                elif [[ -z "$ISSUE_KEY" && ! "$1" =~ ^- ]]; then
                    ISSUE_KEY="$1"
                elif [[ -z "$DURATION_STR" && ! "$1" =~ ^- ]]; then
                    DURATION_STR="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$ISSUE_KEY" ]]; then
        error "Issue key is required. (e.g. jira worklog PROJ-123 2h30m -m \"review\")"
        return 1
    fi

    if [[ -z "$SUBCOMMAND" ]]; then
        if [[ -n "$DURATION_STR" ]]; then
            SUBCOMMAND="add"
        else
            SUBCOMMAND="list"
        fi
    fi

    local jira_bin="${JIRA_CLI_ROOT:-$DIR/..}/bin/jira"
    [[ -x "$jira_bin" ]] || jira_bin="${DIR}/jira"
    local md2jira_bin="${JIRA_CLI_ROOT:-$DIR/..}/bin/md2jira"
    [[ -x "$md2jira_bin" ]] || md2jira_bin="${DIR}/md2jira"

    case "$SUBCOMMAND" in
        list)
            local resp
            resp=$("$jira_bin" GET "/issue/${ISSUE_KEY}/worklog" 2>/dev/null || true)
            case "$OUTPUT_FORMAT" in
                json)
                    echo "$resp" | jq '.worklogs // []'
                    ;;
                table)
                    echo -e "ID\tAUTHOR\tTIME_SPENT\tSTARTED\tCOMMENT"
                    echo "$resp" | jq -r '
                        (.worklogs // [])[] |
                        [
                            .id,
                            (.author.displayName // .author.name // "Unknown"),
                            (.timeSpent // ""),
                            (.started // ""),
                            (
                                if (.comment | type) == "object" then
                                    ([.. | .text? // empty] | join(" ") | gsub("[\t\n\r]"; " "))
                                else
                                    ((.comment // "") | gsub("[\t\n\r]"; " "))
                                end
                            )
                        ] | @tsv
                    ' | column -t -s $'\t'
                    ;;
                md)
                    echo "| ID | Author | Time Spent | Started | Comment |"
                    echo "|---|---|---|---|---|"
                    echo "$resp" | jq -r '
                        (.worklogs // [])[] |
                        "| " + .id + " | " + (.author.displayName // .author.name // "Unknown") + " | " + (.timeSpent // "") + " | " + (.started // "") + " | " +
                        (
                            if (.comment | type) == "object" then
                                ([.. | .text? // empty] | join(" ") | gsub("[\n\r|]"; " "))
                            else
                                ((.comment // "") | gsub("[\n\r|]"; " "))
                            end
                        ) + " |"
                    '
                    ;;
                *)
                    echo "$resp" | jq '.worklogs // []'
                    ;;
            esac
            ;;

        add)
            if [[ -z "$DURATION_STR" ]]; then
                error "Duration is required (e.g. 2h, 30m, 1d 4h)."
                return 1
            fi

            local seconds
            seconds=$(parse_duration_to_seconds "$DURATION_STR")
            if [[ "$seconds" -le 0 ]]; then
                error "Invalid duration: '$DURATION_STR'. Expected format: 2h, 30m, 1d 4h."
                return 1
            fi
            local formatted_time
            formatted_time=$(format_seconds_to_jira_duration "$seconds")

            local payload_file
            payload_file=$(mktemp)
            trap 'rm -f "$payload_file"' RETURN

            if [[ -z "$STARTED_AT" ]]; then
                STARTED_AT=$(date -u +"%Y-%m-%dT%H:%M:%S.000+0000" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S.000+0000")
            fi

            if [[ "${JIRA_API_VERSION:-3}" == "3" ]]; then
                if [[ -n "$COMMENT" ]]; then
                    local adf_body
                    adf_body=$(jira_text_to_adf "$COMMENT")
                    jq -n \
                        --argjson timeSec "$seconds" \
                        --arg started "$STARTED_AT" \
                        --argjson comment "$adf_body" \
                        '{timeSpentSeconds: $timeSec, started: $started, comment: $comment}' > "$payload_file"
                else
                    jq -n \
                        --argjson timeSec "$seconds" \
                        --arg started "$STARTED_AT" \
                        '{timeSpentSeconds: $timeSec, started: $started}' > "$payload_file"
                fi
            else
                local wiki_comment=""
                [[ -n "$COMMENT" ]] && wiki_comment=$(markdown_to_jira "$COMMENT" 2>/dev/null || printf '%s' "$COMMENT")
                jq -n \
                    --argjson timeSec "$seconds" \
                    --arg started "$STARTED_AT" \
                    --arg comment "$wiki_comment" \
                    '(if $comment != "" then {timeSpentSeconds: $timeSec, started: $started, comment: $comment} else {timeSpentSeconds: $timeSec, started: $started} end)' > "$payload_file"
            fi

            if [[ "$DRY_RUN_MODE" == "true" ]]; then
                echo "[DRY-RUN] POST /issue/${ISSUE_KEY}/worklog" >&2
                cat "$payload_file" | jq .
                return 0
            fi

            info "Logging $formatted_time on $ISSUE_KEY..."
            local resp
            resp=$("$jira_bin" POST "/issue/${ISSUE_KEY}/worklog" --data "$payload_file")
            local log_id
            log_id=$(echo "$resp" | jq -r '.id // empty')
            if [[ -n "$log_id" ]]; then
                success "Worklog logged (ID: $log_id): $formatted_time on $ISSUE_KEY"
            else
                error "Failed to log worklog: $resp"
                return 1
            fi
            ;;

        delete)
            if [[ -z "$WORKLOG_ID" ]]; then
                error "Worklog ID is required for delete. (e.g. jira worklog delete $ISSUE_KEY 10550)"
                return 1
            fi
            info "Deleting worklog $WORKLOG_ID from $ISSUE_KEY..."
            "$jira_bin" DELETE "/issue/${ISSUE_KEY}/worklog/${WORKLOG_ID}"
            success "Worklog $WORKLOG_ID deleted."
            ;;
    esac
}
