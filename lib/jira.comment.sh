#!/bin/bash
# Comment management functions for jira CLI
# Handles listing, adding, editing, and deleting comments with Markdown -> ADF conversion for Jira Cloud

jira_comment_main() {
    local SUBCOMMAND=""
    local ISSUE_KEY=""
    local COMMENT_ID=""
    local MESSAGE=""
    local MESSAGE_SET=false
    local OUTPUT_FORMAT="json"
    local DRY_RUN_MODE=false
    local SHOW_HELP=false

    # Check for help flag in arguments
    for arg in "$@"; do
        if [[ "$arg" =~ ^(-h|--help|help)$ ]]; then
            SHOW_HELP=true
            break
        fi
    done

    if [[ "$SHOW_HELP" == "true" ]]; then
        show_help_from_manual "comment" || true
        return 0
    fi

    # Determine subcommand if explicit
    if [[ $# -gt 0 ]]; then
        case "$1" in
            list|ls)
                SUBCOMMAND="list"
                shift
                ;;
            add|create|new)
                SUBCOMMAND="add"
                shift
                ;;
            edit|update)
                SUBCOMMAND="edit"
                shift
                ;;
            delete|rm|del)
                SUBCOMMAND="delete"
                shift
                ;;
        esac
    fi

    # Parse remaining arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -m|--message)
                MESSAGE="$2"
                MESSAGE_SET=true
                shift 2
                ;;
            --output)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN_MODE=true
                shift
                ;;
            -h|--help|help)
                show_help_from_manual "comment" || true
                return 0
                ;;
            *)
                if [[ -z "$ISSUE_KEY" && "$1" =~ ^[A-Za-z0-9_]+-[0-9]+$ ]]; then
                    ISSUE_KEY="$1"
                elif [[ -z "$COMMENT_ID" && ("$SUBCOMMAND" == "edit" || "$SUBCOMMAND" == "delete") && "$1" =~ ^[0-9]+$ ]]; then
                    COMMENT_ID="$1"
                elif [[ -z "$ISSUE_KEY" && ! "$1" =~ ^- ]]; then
                    ISSUE_KEY="$1"
                elif [[ "$MESSAGE_SET" != "true" && ! "$1" =~ ^- ]]; then
                    MESSAGE="$1"
                    MESSAGE_SET=true
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$ISSUE_KEY" ]]; then
        error "Issue key is required. (e.g. jira comment PROJ-123)"
        show_help_from_manual "comment" || true
        return 1
    fi

    # Default action if no message and no subcommand: list comments
    if [[ -z "$SUBCOMMAND" ]]; then
        if [[ "$MESSAGE_SET" == "true" ]]; then
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
            local endpoint="/issue/${ISSUE_KEY}/comment"
            local raw_resp
            raw_resp=$("$jira_bin" GET "$endpoint" 2>/dev/null || true)
            
            if [[ -z "$raw_resp" || ! "$raw_resp" =~ \{ ]]; then
                error "Failed to retrieve comments for $ISSUE_KEY"
                return 1
            fi

            case "$OUTPUT_FORMAT" in
                json)
                    echo "$raw_resp" | jq '.comments // []'
                    ;;
                table)
                    echo -e "ID\tAUTHOR\tCREATED\tBODY"
                    echo "$raw_resp" | jq -r '
                        (.comments // [])[] |
                        [
                            .id,
                            (.author.displayName // .author.name // "Unknown"),
                            (.created // ""),
                            (
                                if (.body | type) == "object" then
                                    ([.. | .text? // empty] | join(" ") | gsub("[\t\n\r]"; " "))
                                else
                                    ((.body // "") | gsub("[\t\n\r]"; " "))
                                end
                            )
                        ] | @tsv
                    ' | column -t -s $'\t'
                    ;;
                md)
                    echo "| ID | Author | Created | Comment |"
                    echo "|---|---|---|---|"
                    echo "$raw_resp" | jq -r '
                        (.comments // [])[] |
                        "| " + .id + " | " + (.author.displayName // .author.name // "Unknown") + " | " + (.created // "") + " | " + 
                        (
                            if (.body | type) == "object" then
                                ([.. | .text? // empty] | join(" ") | gsub("[\n\r|]"; " "))
                            else
                                ((.body // "") | gsub("[\n\r|]"; " "))
                            end
                        ) + " |"
                    '
                    ;;
                *)
                    echo "$raw_resp" | jq '.comments // []'
                    ;;
            esac
            ;;

        add)
            if [[ "$MESSAGE_SET" != "true" || -z "$MESSAGE" ]]; then
                error "Comment message is required. Use: jira comment $ISSUE_KEY \"message\" or -m \"message\""
                return 1
            fi

            # Read from stdin if "-"
            if [[ "$MESSAGE" == "-" ]]; then
                if [[ -t 0 ]]; then
                    error "No input on stdin."
                    return 1
                fi
                MESSAGE=$(cat)
            # Read from file if "@file"
            elif [[ "$MESSAGE" == @* ]]; then
                local filepath="${MESSAGE#@}"
                if [[ ! -f "$filepath" ]]; then
                    error "File not found: $filepath"
                    return 1
                fi
                MESSAGE=$(cat "$filepath")
            fi

            local payload_file
            payload_file=$(mktemp)
            trap 'rm -f "$payload_file"' RETURN

            if [[ "${JIRA_API_VERSION:-3}" == "3" ]]; then
                local adf_body
                adf_body=$(jira_text_to_adf "$MESSAGE")
                jq -n --argjson body "$adf_body" '{body: $body}' > "$payload_file"
            else
                local wiki_body
                wiki_body=$(markdown_to_jira "$MESSAGE" 2>/dev/null || printf '%s' "$MESSAGE")
                jq -n --arg msg "$wiki_body" '{body: $msg}' > "$payload_file"
            fi

            if [[ "$DRY_RUN_MODE" == "true" ]]; then
                echo "[DRY-RUN] POST /issue/${ISSUE_KEY}/comment" >&2
                cat "$payload_file" | jq .
                return 0
            fi

            info "Adding comment to $ISSUE_KEY..."
            "$jira_bin" POST "/issue/${ISSUE_KEY}/comment" --data "$payload_file"
            ;;

        edit)
            if [[ -z "$COMMENT_ID" ]]; then
                error "Comment ID is required for edit. (e.g. jira comment edit $ISSUE_KEY 10050 -m \"new message\")"
                return 1
            fi
            if [[ "$MESSAGE_SET" != "true" || -z "$MESSAGE" ]]; then
                error "New comment message is required."
                return 1
            fi

            if [[ "$MESSAGE" == "-" ]]; then
                MESSAGE=$(cat)
            elif [[ "$MESSAGE" == @* ]]; then
                local filepath="${MESSAGE#@}"
                [[ -f "$filepath" ]] || { error "File not found: $filepath"; return 1; }
                MESSAGE=$(cat "$filepath")
            fi

            local payload_file
            payload_file=$(mktemp)
            trap 'rm -f "$payload_file"' RETURN

            if [[ "${JIRA_API_VERSION:-3}" == "3" ]]; then
                local adf_body
                adf_body=$(jira_text_to_adf "$MESSAGE")
                jq -n --argjson body "$adf_body" '{body: $body}' > "$payload_file"
            else
                local wiki_body
                wiki_body=$(markdown_to_jira "$MESSAGE" 2>/dev/null || printf '%s' "$MESSAGE")
                jq -n --arg msg "$wiki_body" '{body: $msg}' > "$payload_file"
            fi

            if [[ "$DRY_RUN_MODE" == "true" ]]; then
                echo "[DRY-RUN] PUT /issue/${ISSUE_KEY}/comment/${COMMENT_ID}" >&2
                cat "$payload_file" | jq .
                return 0
            fi

            info "Updating comment $COMMENT_ID on $ISSUE_KEY..."
            "$jira_bin" PUT "/issue/${ISSUE_KEY}/comment/${COMMENT_ID}" --data "$payload_file"
            ;;

        delete)
            if [[ -z "$COMMENT_ID" ]]; then
                error "Comment ID is required for delete. (e.g. jira comment delete $ISSUE_KEY 10050)"
                return 1
            fi

            if [[ "$DRY_RUN_MODE" == "true" ]]; then
                echo "[DRY-RUN] DELETE /issue/${ISSUE_KEY}/comment/${COMMENT_ID}" >&2
                return 0
            fi

            info "Deleting comment $COMMENT_ID from $ISSUE_KEY..."
            "$jira_bin" DELETE "/issue/${ISSUE_KEY}/comment/${COMMENT_ID}"
            success "Comment $COMMENT_ID deleted."
            ;;
    esac
}
