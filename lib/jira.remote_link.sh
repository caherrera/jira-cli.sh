#!/bin/bash
# Remote web links management for jira CLI
# Handles linking URLs (GitLab MRs, GitHub PRs, Confluence pages, etc.) to Jira issues

jira_remote_link_main() {
    local SUBCOMMAND=""
    local ISSUE_KEY=""
    local TARGET_URL=""
    local LINK_ID=""
    local TITLE=""
    local SUMMARY=""
    local RELATIONSHIP="relates to"
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
        show_help_from_manual "link" || true
        return 0
    fi

    if [[ $# -gt 0 ]]; then
        case "$1" in
            add|create)
                SUBCOMMAND="add"; shift ;;
            list|ls)
                SUBCOMMAND="list"; shift ;;
            delete|rm)
                SUBCOMMAND="delete"; shift ;;
        esac
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --title)
                TITLE="$2"; shift 2 ;;
            --summary)
                SUMMARY="$2"; shift 2 ;;
            --relationship)
                RELATIONSHIP="$2"; shift 2 ;;
            --output)
                OUTPUT_FORMAT="$2"; shift 2 ;;
            --dry-run)
                DRY_RUN_MODE=true; shift ;;
            -h|--help|help)
                show_help_from_manual "link" || true; return 0 ;;
            *)
                if [[ -z "$ISSUE_KEY" && "$1" =~ ^[A-Za-z0-9_]+-[0-9]+$ ]]; then
                    ISSUE_KEY="$1"
                elif [[ -z "$TARGET_URL" && "$1" =~ ^https?:// ]]; then
                    TARGET_URL="$1"
                elif [[ -z "$LINK_ID" && "$SUBCOMMAND" == "delete" && "$1" =~ ^[0-9]+$ ]]; then
                    LINK_ID="$1"
                elif [[ -z "$ISSUE_KEY" && ! "$1" =~ ^- ]]; then
                    ISSUE_KEY="$1"
                elif [[ -z "$TARGET_URL" && ! "$1" =~ ^- ]]; then
                    TARGET_URL="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$ISSUE_KEY" ]]; then
        error "Issue key is required. (e.g. jira link-url PROJ-123 https://...)"
        return 1
    fi

    if [[ -z "$SUBCOMMAND" ]]; then
        if [[ -n "$TARGET_URL" ]]; then
            SUBCOMMAND="add"
        else
            SUBCOMMAND="list"
        fi
    fi

    local jira_bin="${JIRA_CLI_ROOT:-$DIR/..}/bin/jira"
    [[ -x "$jira_bin" ]] || jira_bin="${DIR}/jira"

    case "$SUBCOMMAND" in
        list)
            local resp
            resp=$("$jira_bin" GET "/issue/${ISSUE_KEY}/remotelink" 2>/dev/null || true)
            case "$OUTPUT_FORMAT" in
                json)
                    echo "$resp" | jq '.'
                    ;;
                table)
                    echo -e "ID\tTITLE\tRELATIONSHIP\tURL"
                    echo "$resp" | jq -r '
                        (if type == "array" then . else [] end)[] |
                        [.id, (.object.title // ""), (.relationship // ""), (.object.url // "")] | @tsv
                    ' | column -t -s $'\t'
                    ;;
                md)
                    echo "| ID | Title | Relationship | URL |"
                    echo "|---|---|---|---|"
                    echo "$resp" | jq -r '
                        (if type == "array" then . else [] end)[] |
                        "| " + (.id|tostring) + " | " + (.object.title // "") + " | " + (.relationship // "") + " | " + (.object.url // "") + " |"
                    '
                    ;;
                *)
                    echo "$resp" | jq '.'
                    ;;
            esac
            ;;

        add)
            if [[ -z "$TARGET_URL" ]]; then
                error "Target URL is required. (e.g. jira link-url $ISSUE_KEY https://gitlab.com/... --title \"MR !45\")"
                return 1
            fi
            [[ -z "$TITLE" ]] && TITLE="$TARGET_URL"

            local payload
            payload=$(jq -n \
                --arg url "$TARGET_URL" \
                --arg title "$TITLE" \
                --arg summary "$SUMMARY" \
                --arg rel "$RELATIONSHIP" \
                '{
                    object: {
                        url: $url,
                        title: $title,
                        summary: $summary
                    },
                    relationship: $rel
                }')

            if [[ "$DRY_RUN_MODE" == "true" ]]; then
                echo "[DRY-RUN] POST /issue/${ISSUE_KEY}/remotelink" >&2
                echo "$payload" | jq .
                return 0
            fi

            local payload_file
            payload_file=$(mktemp)
            trap 'rm -f "$payload_file"' RETURN
            printf '%s' "$payload" > "$payload_file"

            info "Linking URL '$TARGET_URL' to $ISSUE_KEY..."
            local resp
            resp=$("$jira_bin" POST "/issue/${ISSUE_KEY}/remotelink" --data "$payload_file")
            local link_id
            link_id=$(echo "$resp" | jq -r '.id // empty')
            if [[ -n "$link_id" ]]; then
                success "Remote link created (ID: $link_id): $TITLE -> $TARGET_URL"
            else
                error "Failed to create remote link: $resp"
                return 1
            fi
            ;;

        delete)
            if [[ -z "$LINK_ID" ]]; then
                error "Remote link ID is required for delete. (e.g. jira link-url delete $ISSUE_KEY 10023)"
                return 1
            fi
            info "Deleting remote link $LINK_ID from $ISSUE_KEY..."
            "$jira_bin" DELETE "/issue/${ISSUE_KEY}/remotelink/${LINK_ID}"
            success "Remote link $LINK_ID deleted."
            ;;
    esac
}
