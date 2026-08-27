#!/bin/bash
# Transition and workflow management for jira CLI
# Handles listing transitions, applying specific transitions, and automatic Done/Redo resolution

# Regex to identify discard states
DISCARD_REGEX='(?i)(discard|descart|cancel|rechaz|reject|wont[[:space:]]*fix|won'\''t[[:space:]]*fix|invalid|duplicate|obsolete|not[[:space:]]*do|no[[:space:]]se[[:space:]]hara|no[[:space:]]se[[:space:]]har[aá])'

select_next_done_transition() {
    local transitions_json="$1"
    local done_pick
    done_pick=$(echo "$transitions_json" | jq -r --arg re "$DISCARD_REGEX" '
        (.transitions // [])
        | map(select(
            (.to.statusCategory.key // "" | ascii_downcase) == "done"
            and ((.name // "" | test($re;"i")) | not)
            and ((.to.name // "" | test($re;"i")) | not)
        ))
        | (.[0] // empty)
        | if . == null then "" else "\(.id)|\(.to.name)|done" end
    ')
    [[ -n "$done_pick" ]] && { echo "$done_pick"; return 0; }

    local inprog_pick
    inprog_pick=$(echo "$transitions_json" | jq -r --arg re "$DISCARD_REGEX" '
        (.transitions // [])
        | map(select(
            ((.to.statusCategory.key // "" | ascii_downcase) | test("inprogress|indeterminate";"i"))
            and ((.name // "" | test($re;"i")) | not)
            and ((.to.name // "" | test($re;"i")) | not)
        ))
        | if length >= 1 then "\(.[] .id)|\(.[] .to.name)|\(.[] .to.statusCategory.key)" else "" end
    ')
    [[ -n "$inprog_pick" ]] && { echo "$inprog_pick"; return 0; }

    local any_pick
    any_pick=$(echo "$transitions_json" | jq -r --arg re "$DISCARD_REGEX" '
        (.transitions // [])
        | map(select(
            ((.name // "" | test($re;"i")) | not)
            and ((.to.name // "" | test($re;"i")) | not)
        )) as $clean
        | if ($clean | length) == 0 then "" 
          elif ($clean | length) == 1 then ($clean[0] | "\(.id)|\(.to.name)|\(.to.statusCategory.key)")
          else (
              ($clean
               | map(select((.to.statusCategory.key // "" | ascii_downcase) | test("inprogress|indeterminate";"i")))
               | .[0]?) as $pref
              | if $pref != null then "\($pref.id)|\($pref.to.name)|\($pref.to.statusCategory.key)"
                else ($clean[0] | "\(.id)|\(.to.name)|\(.to.statusCategory.key)")
                end
            )
          end
    ')
    [[ -n "$any_pick" ]] && { echo "$any_pick"; return 0; }

    return 1
}

execute_auto_done() {
    local issue_key="$1"
    local comment_msg="${2:-}"
    local discard_mode="${3:-false}"
    local jira_bin="${JIRA_CLI_ROOT:-$DIR/..}/bin/jira"
    [[ -x "$jira_bin" ]] || jira_bin="${DIR}/jira"

    info "Analyzing issue $issue_key status..."
    local issue_data
    issue_data=$("$jira_bin" issue "$issue_key" 2>/dev/null || true)
    
    if [[ -z "$issue_data" || "$issue_data" == "null" ]]; then
        error "Could not retrieve issue $issue_key"
        return 1
    fi

    local current_status current_category
    current_status=$(echo "$issue_data" | jq -r '.fields.status.name // ""')
    current_category=$(echo "$issue_data" | jq -r '.fields.status.statusCategory.name // ""')

    if [[ "$current_category" == "Done" && "$discard_mode" != "true" ]]; then
        success "Issue $issue_key is already in Done category ($current_status)."
        if [[ -n "$comment_msg" ]]; then
            "$jira_bin" comment "$issue_key" -m "$comment_msg" >/dev/null 2>&1 || true
        fi
        return 0
    fi

    local step=1
    local max_steps=10
    while [[ $step -le $max_steps ]]; do
        local transitions_json
        transitions_json=$("$jira_bin" issue "$issue_key" --transitions 2>/dev/null || true)
        if [[ -z "$transitions_json" ]]; then
            error "Could not retrieve transitions for $issue_key"
            return 1
        fi

        local pick
        pick=$(select_next_done_transition "$transitions_json")
        if [[ -z "$pick" ]]; then
            warning "No further automatic transition path found for $issue_key."
            break
        fi

        local tr_id tr_name tr_cat
        IFS='|' read -r tr_id tr_name tr_cat <<< "$pick"
        info "Step $step: applying transition '$tr_name' (ID: $tr_id)..."
        if ! "$jira_bin" issue "$issue_key" --transitions --to "$tr_id" >/dev/null 2>&1; then
            warning "Transition $tr_id failed."
            break
        fi

        sleep 1
        issue_data=$("$jira_bin" issue "$issue_key" 2>/dev/null || true)
        current_status=$(echo "$issue_data" | jq -r '.fields.status.name // ""')
        current_category=$(echo "$issue_data" | jq -r '.fields.status.statusCategory.name // ""')
        
        if [[ "$current_category" == "Done" ]]; then
            success "Issue $issue_key successfully transitioned to Done ($current_status)."
            if [[ -n "$comment_msg" ]]; then
                info "Adding resolution comment..."
                "$jira_bin" comment "$issue_key" -m "$comment_msg" >/dev/null 2>&1 || true
            fi
            return 0
        fi
        ((step++))
    done

    if [[ "$current_category" == "Done" ]]; then
        success "Issue $issue_key reached Done."
        return 0
    else
        warning "Issue $issue_key ended in '$current_status' ($current_category)."
        return 1
    fi
}

jira_transition_main() {
    local SUBCOMMAND=""
    local ISSUE_KEY=""
    local TARGET_SPEC=""
    local COMMENT_MSG=""
    local DISCARD_MODE=false
    local OUTPUT_FORMAT="json"
    local SHOW_HELP=false

    for arg in "$@"; do
        if [[ "$arg" =~ ^(-h|--help|help)$ ]]; then
            SHOW_HELP=true
            break
        fi
    done

    if [[ "$SHOW_HELP" == "true" ]]; then
        show_help_from_manual "transition" || true
        return 0
    fi

    if [[ $# -gt 0 ]]; then
        case "$1" in
            list|ls)
                SUBCOMMAND="list"; shift ;;
            to)
                SUBCOMMAND="to"; shift ;;
            done)
                SUBCOMMAND="done"; shift ;;
            redo|reopen)
                SUBCOMMAND="redo"; shift ;;
        esac
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -m|--message)
                COMMENT_MSG="$2"; shift 2 ;;
            --discard)
                DISCARD_MODE=true; shift ;;
            --output)
                OUTPUT_FORMAT="$2"; shift 2 ;;
            -h|--help|help)
                show_help_from_manual "transition" || true; return 0 ;;
            *)
                if [[ -z "$ISSUE_KEY" && "$1" =~ ^[A-Za-z0-9_]+-[0-9]+$ ]]; then
                    ISSUE_KEY="$1"
                elif [[ "$SUBCOMMAND" == "to" && -z "$TARGET_SPEC" && ! "$1" =~ ^- ]]; then
                    TARGET_SPEC="$1"
                elif [[ -z "$ISSUE_KEY" && ! "$1" =~ ^- ]]; then
                    ISSUE_KEY="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$ISSUE_KEY" ]]; then
        error "Issue key is required. (e.g. jira transition PROJ-123)"
        show_help_from_manual "transition" || true
        return 1
    fi

    local jira_bin="${JIRA_CLI_ROOT:-$DIR/..}/bin/jira"
    [[ -x "$jira_bin" ]] || jira_bin="${DIR}/jira"

    [[ -z "$SUBCOMMAND" ]] && SUBCOMMAND="list"

    case "$SUBCOMMAND" in
        list)
            local raw_resp
            raw_resp=$("$jira_bin" GET "/issue/${ISSUE_KEY}/transitions" 2>/dev/null || true)
            case "$OUTPUT_FORMAT" in
                json)
                    echo "$raw_resp" | jq '.transitions // []'
                    ;;
                table)
                    echo -e "ID\tTRANSITION\tTARGET_STATUS\tCATEGORY"
                    echo "$raw_resp" | jq -r '
                        (.transitions // [])[] |
                        [.id, .name, .to.name, .to.statusCategory.name] | @tsv
                    ' | column -t -s $'\t'
                    ;;
                md)
                    echo "| ID | Transition | Target Status | Category |"
                    echo "|---|---|---|---|"
                    echo "$raw_resp" | jq -r '
                        (.transitions // [])[] |
                        "| " + .id + " | " + .name + " | " + .to.name + " | " + .to.statusCategory.name + " |"
                    '
                    ;;
                *)
                    echo "$raw_resp" | jq '.transitions // []'
                    ;;
            esac
            ;;
        to)
            if [[ -z "$TARGET_SPEC" ]]; then
                error "Target transition ID or status name is required. Use: jira transition to $ISSUE_KEY <SPEC>"
                return 1
            fi
            "$jira_bin" issue "$ISSUE_KEY" --transition "$TARGET_SPEC"
            ;;
        done)
            execute_auto_done "$ISSUE_KEY" "$COMMENT_MSG" "$DISCARD_MODE"
            ;;
        redo)
            info "Reopening issue $ISSUE_KEY..."
            local transitions_json
            transitions_json=$("$jira_bin" GET "/issue/${ISSUE_KEY}/transitions" 2>/dev/null || true)
            local redo_id
            redo_id=$(echo "$transitions_json" | jq -r '
                (.transitions // []) |
                map(select(
                    (.to.statusCategory.key // "" | ascii_downcase) == "new"
                    or ((.name // "" | ascii_downcase) | test("reopen|reabrir|redo|to do|backlog";"i"))
                    or ((.to.name // "" | ascii_downcase) | test("reopen|reabrir|redo|to do|backlog";"i"))
                )) | .[0].id // empty
            ')
            if [[ -n "$redo_id" ]]; then
                "$jira_bin" issue "$ISSUE_KEY" --transitions --to "$redo_id"
                success "Issue $ISSUE_KEY reopened."
            else
                error "No suitable reopen/redo transition found for $ISSUE_KEY."
                return 1
            fi
            ;;
    esac
}
