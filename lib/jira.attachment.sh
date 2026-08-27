#!/bin/bash
# Attachment management functions for jira CLI
# Handles uploading files with Jira Cloud security headers, listing, and downloading attachments

jira_attachment_main() {
    local SUBCOMMAND=""
    local ISSUE_KEY=""
    local ATTACHMENT_ID=""
    local OUTPUT_FILE=""
    local OUTPUT_FORMAT="json"
    local FILES=()
    local DRY_RUN_MODE=false
    local SHOW_HELP=false

    for arg in "$@"; do
        if [[ "$arg" =~ ^(-h|--help|help)$ ]]; then
            SHOW_HELP=true
            break
        fi
    done

    if [[ "$SHOW_HELP" == "true" ]]; then
        show_help_from_manual "attach" || true
        return 0
    fi

    if [[ $# -gt 0 ]]; then
        case "$1" in
            upload|add|post)
                SUBCOMMAND="upload"; shift ;;
            list|ls)
                SUBCOMMAND="list"; shift ;;
            download|get)
                SUBCOMMAND="download"; shift ;;
            delete|rm)
                SUBCOMMAND="delete"; shift ;;
        esac
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -o|--output-file)
                OUTPUT_FILE="$2"; shift 2 ;;
            --output)
                OUTPUT_FORMAT="$2"; shift 2 ;;
            --dry-run)
                DRY_RUN_MODE=true; shift ;;
            -h|--help|help)
                show_help_from_manual "attach" || true; return 0 ;;
            *)
                if [[ -z "$ISSUE_KEY" && "$1" =~ ^[A-Za-z0-9_]+-[0-9]+$ ]]; then
                    ISSUE_KEY="$1"
                elif [[ -z "$ATTACHMENT_ID" && ("$SUBCOMMAND" == "download" || "$SUBCOMMAND" == "delete") && "$1" =~ ^[0-9]+$ ]]; then
                    ATTACHMENT_ID="$1"
                elif [[ -f "$1" ]]; then
                    FILES+=("$1")
                elif [[ -z "$ISSUE_KEY" && ! "$1" =~ ^- ]]; then
                    ISSUE_KEY="$1"
                else
                    FILES+=("$1")
                fi
                shift
                ;;
        esac
    done

    # Default action
    if [[ -z "$SUBCOMMAND" ]]; then
        if [[ ${#FILES[@]} -gt 0 ]]; then
            SUBCOMMAND="upload"
        else
            SUBCOMMAND="list"
        fi
    fi

    local jira_bin="${JIRA_CLI_ROOT:-$DIR/..}/bin/jira"
    [[ -x "$jira_bin" ]] || jira_bin="${DIR}/jira"

    case "$SUBCOMMAND" in
        list)
            if [[ -z "$ISSUE_KEY" ]]; then
                error "Issue key is required to list attachments. (e.g. jira attach list PROJ-123)"
                return 1
            fi
            local issue_data
            issue_data=$("$jira_bin" GET "/issue/${ISSUE_KEY}?fields=attachment" 2>/dev/null || true)
            case "$OUTPUT_FORMAT" in
                json)
                    echo "$issue_data" | jq '.fields.attachment // []'
                    ;;
                table)
                    echo -e "ID\tFILENAME\tSIZE\tAUTHOR\tCREATED"
                    echo "$issue_data" | jq -r '
                        (.fields.attachment // [])[] |
                        [.id, .filename, (.size|tostring), (.author.displayName // .author.name // "Unknown"), .created] | @tsv
                    ' | column -t -s $'\t'
                    ;;
                md)
                    echo "| ID | Filename | Size (bytes) | Author | Created |"
                    echo "|---|---|---|---|---|"
                    echo "$issue_data" | jq -r '
                        (.fields.attachment // [])[] |
                        "| " + .id + " | " + .filename + " | " + (.size|tostring) + " | " + (.author.displayName // .author.name // "Unknown") + " | " + .created + " |"
                    '
                    ;;
                *)
                    echo "$issue_data" | jq '.fields.attachment // []'
                    ;;
            esac
            ;;

        upload)
            if [[ -z "$ISSUE_KEY" ]]; then
                error "Issue key is required. (e.g. jira attach PROJ-123 file.png)"
                return 1
            fi
            if [[ ${#FILES[@]} -eq 0 ]]; then
                error "At least one file must be specified to attach."
                return 1
            fi

            for f in "${FILES[@]}"; do
                if [[ ! -f "$f" ]]; then
                    error "File does not exist: $f"
                    return 1
                fi
            done

            local base_host="${JIRA_HOST%/}"
            if [[ ! "$base_host" =~ ^https?:// ]]; then
                base_host="https://$base_host"
            fi
            local api_ver="${JIRA_API_VERSION:-3}"
            local upload_url="${base_host}/rest/api/${api_ver}/issue/${ISSUE_KEY}/attachments"

            # Prepare curl args with multipart
            local curl_cmd=(curl --compressed --silent --location)
            curl_cmd+=(-H "X-Atlassian-Token: no-check")

            # Determine auth header
            if [[ -n "$JIRA_EMAIL" && -n "$JIRA_API_TOKEN" ]]; then
                local b64; b64=$(printf "%s:%s" "$JIRA_EMAIL" "$JIRA_API_TOKEN" | base64 | tr -d '\n')
                curl_cmd+=(-H "Authorization: Basic $b64")
            elif [[ -n "$JIRA_USER" && -n "$JIRA_PASSWORD" ]]; then
                local b64; b64=$(printf "%s:%s" "$JIRA_USER" "$JIRA_PASSWORD" | base64 | tr -d '\n')
                curl_cmd+=(-H "Authorization: Basic $b64")
            elif [[ -n "$JIRA_TOKEN" ]]; then
                curl_cmd+=(-H "Authorization: Bearer $JIRA_TOKEN")
            fi

            for f in "${FILES[@]}"; do
                curl_cmd+=(-F "file=@$f")
            done
            curl_cmd+=("$upload_url")

            if [[ "$DRY_RUN_MODE" == "true" ]]; then
                echo "[DRY-RUN] POST $upload_url (X-Atlassian-Token: no-check, files: ${FILES[*]})"
                return 0
            fi

            info "Uploading ${#FILES[@]} attachment(s) to $ISSUE_KEY..."
            local resp
            resp=$("${curl_cmd[@]}")
            if echo "$resp" | jq -e 'type == "array" and length > 0' >/dev/null 2>&1; then
                success "Attached successfully:"
                echo "$resp" | jq -r '.[] | "  - \(.filename) (ID: \(.id), Size: \(.size) bytes)"'
            else
                error "Failed to upload attachments: $resp"
                return 1
            fi
            ;;

        download)
            if [[ -z "$ATTACHMENT_ID" ]]; then
                error "Attachment ID is required to download. Use: jira attach download <ID> [-o output_file]"
                return 1
            fi

            local base_host="${JIRA_HOST%/}"
            [[ ! "$base_host" =~ ^https?:// ]] && base_host="https://$base_host"
            local api_ver="${JIRA_API_VERSION:-3}"
            local dl_url="${base_host}/rest/api/${api_ver}/attachment/content/${ATTACHMENT_ID}"

            # If no output file specified, get filename metadata first
            if [[ -z "$OUTPUT_FILE" ]]; then
                local meta
                meta=$("$jira_bin" GET "/attachment/${ATTACHMENT_ID}" 2>/dev/null || true)
                local orig_filename
                orig_filename=$(echo "$meta" | jq -r '.filename // empty')
                OUTPUT_FILE="${orig_filename:-attachment_${ATTACHMENT_ID}}"
            fi

            local curl_cmd=(curl --compressed --silent --location)
            if [[ -n "$JIRA_EMAIL" && -n "$JIRA_API_TOKEN" ]]; then
                local b64; b64=$(printf "%s:%s" "$JIRA_EMAIL" "$JIRA_API_TOKEN" | base64 | tr -d '\n')
                curl_cmd+=(-H "Authorization: Basic $b64")
            elif [[ -n "$JIRA_TOKEN" ]]; then
                curl_cmd+=(-H "Authorization: Bearer $JIRA_TOKEN")
            fi
            curl_cmd+=(-o "$OUTPUT_FILE" "$dl_url")

            info "Downloading attachment $ATTACHMENT_ID to $OUTPUT_FILE..."
            "${curl_cmd[@]}"
            if [[ -f "$OUTPUT_FILE" ]]; then
                success "Downloaded attachment to: $OUTPUT_FILE"
            else
                error "Download failed."
                return 1
            fi
            ;;

        delete)
            if [[ -z "$ATTACHMENT_ID" ]]; then
                error "Attachment ID is required to delete."
                return 1
            fi
            info "Deleting attachment $ATTACHMENT_ID..."
            "$jira_bin" DELETE "/attachment/${ATTACHMENT_ID}"
            success "Attachment $ATTACHMENT_ID deleted."
            ;;
    esac
}
