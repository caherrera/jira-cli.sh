#!/bin/bash
# Branch management functions for jira CLI
# Handles branch name generation from Jira tickets, sanitization, and git operations

normalize_for_match() {
    printf '%s' "$1" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null | tr '[:upper:]' '[:lower:]' || printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

determine_branch_prefix() {
    local type="$1"
    local priority="$2"
    
    local type_norm
    type_norm=$(normalize_for_match "$type")
    local priority_norm
    priority_norm=$(normalize_for_match "$priority")
    local critical_priorities="blocker critical highest high mayor alta p0 p1 urgente sev-1 sev1 severidad-1"
    local prefix=""
    
    case "$type_norm" in
        bug|defect|error|bugfix|falla|fallo|defecto)
            if [[ " $critical_priorities " == *" $priority_norm "* ]]; then
                prefix="hotfix"
            else
                prefix="bugfix"
            fi
            ;;
        incident|incidente|production-incident|major-incident|problema-produccion)
            prefix="hotfix"
            ;;
        task|tarea|sub-task|subtask|story-task|technical-task|"solicitud de identidad en aws")
            prefix="task"
            ;;
        support|support-task|soporte)
            if [[ " $critical_priorities " == *" $priority_norm "* ]]; then
                prefix="hotfix"
            else
                prefix="fix"
            fi
            ;;
        chore|maintenance|maintenance-task|mantenimiento|operacion|"deuda tecnica"|kaizen)
            prefix="chore"
            ;;
        story|user-story|feature|improvement|enhancement|epic|historia|mejora|mejoras|feature-request|"historia funcional"|"historia tecnica"|"collocated design")
            prefix="feature"
            ;;
        "epica de discovery"|spike|experimentos|hypothesis|discovery|risk|riesgo)
            prefix="spike"
            ;;
        "release candidate")
            prefix="release"
            ;;
        *)
            if [[ "$type_norm" == *"bug"* || "$type_norm" == *"error"* ]]; then
                if [[ " $critical_priorities " == *" $priority_norm "* ]]; then
                    prefix="hotfix"
                else
                    prefix="bugfix"
                fi
            elif [[ "$type_norm" == *"task"* ]]; then
                prefix="task"
            elif [[ "$type_norm" == *"soport"* ]]; then
                if [[ " $critical_priorities " == *" $priority_norm "* ]]; then
                    prefix="hotfix"
                else
                    prefix="fix"
                fi
            elif [[ "$type_norm" == *"mainten"* || "$type_norm" == *"oper"* || "$type_norm" == *"deuda"* ]]; then
                prefix="chore"
            else
                prefix="feature"
            fi
            ;;
    esac
    
    echo "${prefix:-feature}"
}

sanitize_text() {
    local text="$1"
    
    # Remove leading and trailing spaces
    text="${text#"${text%%[![:space:]]*}"}"
    text="${text%"${text##*[![:space:]]}"}"
    
    # Convert accented vowels
    text="${text//á/a}"; text="${text//à/a}"; text="${text//â/a}"; text="${text//ã/a}"; text="${text//ä/a}"; text="${text//å/a}"
    text="${text//é/e}"; text="${text//è/e}"; text="${text//ê/e}"; text="${text//ë/e}"
    text="${text//í/i}"; text="${text//ì/i}"; text="${text//î/i}"; text="${text//ï/i}"
    text="${text//ó/o}"; text="${text//ò/o}"; text="${text//ô/o}"; text="${text//õ/o}"; text="${text//ö/o}"
    text="${text//ú/u}"; text="${text//ù/u}"; text="${text//û/u}"; text="${text//ü/u}"
    text="${text//ñ/n}"; text="${text//ç/c}"
    text="${text//Á/A}"; text="${text//À/A}"; text="${text//Â/A}"; text="${text//Ã/A}"; text="${text//Ä/A}"; text="${text//Å/A}"
    text="${text//É/E}"; text="${text//È/E}"; text="${text//Ê/E}"; text="${text//Ë/E}"
    text="${text//Í/I}"; text="${text//Ì/I}"; text="${text//Î/I}"; text="${text//Ï/I}"
    text="${text//Ó/O}"; text="${text//Ò/O}"; text="${text//Ô/O}"; text="${text//Õ/O}"; text="${text//Ö/O}"
    text="${text//Ú/U}"; text="${text//Ù/U}"; text="${text//Û/U}"; text="${text//Ü/U}"
    text="${text//Ñ/N}"; text="${text//Ç/C}"
    
    # Remove quotes and special characters
    text="${text//\"/}"; text="${text//\'/}"; text="${text//\`/}"
    text="${text//\(/}"; text="${text//\)/}"
    text="${text//\[/}"; text="${text//\]/}"
    text="${text//\{/}"; text="${text//\}/}"
    text="${text//\</}"; text="${text//\>/}"
    text="${text//\&/and}"; text="${text//\@/at}"
    text="${text//\#/}"; text="${text//\$/}"; text="${text//\%/}"
    text="${text//\!/}"; text="${text//\?/}"
    text="${text//\*/}"; text="${text//\+/}"; text="${text//\=/}"
    text="${text//\|/}"; text="${text//\\/}"; text="${text//\;/}"
    text="${text//\:/}"; text="${text//\,/}"; text="${text//\./}"
    text="${text//\^/}"; text="${text//\~/}"
    
    echo "$text"
}

generate_branch_slug() {
    local summary="$1"
    summary=$(sanitize_text "$summary")
    summary=$(echo "$summary" | tr '[:upper:]' '[:lower:]')
    summary="${summary// /-}"
    
    local slug=""
    local i
    for (( i=0; i<${#summary}; i++ )); do
        local char="${summary:$i:1}"
        if [[ "$char" =~ ^[a-z0-9-]$ ]]; then
            slug="${slug}${char}"
        else
            slug="${slug}-"
        fi
    done
    
    while [[ "$slug" == *"--"* ]]; do
        slug="${slug//--/-}"
    done
    
    slug="${slug#-}"
    slug="${slug%-}"
    [ -z "$slug" ] && slug="no-description"
    echo "$slug"
}

build_branch_name() {
    local prefix="$1"
    local key="$2"
    local summary="$3"
    local max_len=63

    local base_prefix="$prefix/$key"
    local base_prefix_with_dash="$base_prefix-"
    local slug
    slug=$(generate_branch_slug "$summary")
    local branch_name=""

    [ -z "$slug" ] && slug="no-description"
    branch_name="$base_prefix-$slug"

    while (( ${#branch_name} > max_len )); do
        local words=()
        IFS='-' read -ra words <<< "$slug"

        if (( ${#words[@]} < 3 )); then
            local allowed_slug_len=$((max_len - ${#base_prefix_with_dash}))
            slug="${slug:0:allowed_slug_len}"
            slug="${slug%-}"
            [ -z "$slug" ] && slug="x"
            branch_name="$base_prefix-$slug"
            break
        fi

        local new_word_count=$((${#words[@]} - 2))
        slug=""
        for (( i=0; i<new_word_count; i++ )); do
            if [ -n "$slug" ]; then
                slug="${slug}-${words[$i]}"
            else
                slug="${words[$i]}"
            fi
        done

        if [ -z "$slug" ]; then
            branch_name="$base_prefix"
        else
            branch_name="$base_prefix-$slug"
        fi
    done
    
    local clean_name=""
    local i
    for (( i=0; i<${#branch_name}; i++ )); do
        local char="${branch_name:$i:1}"
        if [[ "$char" =~ ^[a-zA-Z0-9/_-]$ ]]; then
            clean_name="${clean_name}${char}"
        fi
    done
    
    echo "$clean_name"
}

is_protected_branch() {
    local branch="$1"
    local protected_branches=("master" "main" "develop" "development" "production" "prod" "staging" "stage" "release")
    for protected in "${protected_branches[@]}"; do
        if [ "$branch" = "$protected" ]; then
            return 0
        fi
    done
    if [[ "$branch" =~ ^release/ ]] || [[ "$branch" =~ ^hotfix/ ]]; then
        return 0
    fi
    return 1
}

get_default_branch() {
    local default_branch
    default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    if [ -z "$default_branch" ]; then
        default_branch=$(git config --get init.defaultBranch 2>/dev/null)
        if [ -z "$default_branch" ]; then
            if git rev-parse --verify main >/dev/null 2>&1; then
                default_branch="main"
            elif git rev-parse --verify master >/dev/null 2>&1; then
                default_branch="master"
            fi
        fi
    fi
    echo "$default_branch"
}

jira_branch_main() {
    local RENAME_MODE=false
    local DRY_RUN=false
    local QUICK_MODE=false
    local ISSUE_KEY=""
    local BRANCH_SUMMARY=""
    local BRANCH_PREFIX=""
    local FRESH_REMOTE_BASE=false
    local SHOW_HELP=false

    # Normalize subcommands if passed as "create KEY" or "rename KEY"
    if [[ $# -gt 0 && ("$1" == "create" || "$1" == "new") ]]; then
        shift
    elif [[ $# -gt 0 && "$1" == "rename" ]]; then
        RENAME_MODE=true
        shift
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            -N|--dry-run)
                DRY_RUN=true; shift ;;
            -Q|--quick)
                QUICK_MODE=true; shift ;;
            -m|--rename)
                RENAME_MODE=true; shift ;;
            -F|--fresh)
                FRESH_REMOTE_BASE=true; shift ;;
            --summary=*)
                BRANCH_SUMMARY="${1#*=}"; shift ;;
            --summary|-t)
                BRANCH_SUMMARY="$2"; shift 2 ;;
            --prefix=*)
                BRANCH_PREFIX="${1#*=}"; shift ;;
            --prefix)
                BRANCH_PREFIX="$2"; shift 2 ;;
            -h|--help|help)
                SHOW_HELP=true; shift ;;
            *)
                if [[ -z "$ISSUE_KEY" && ! "$1" =~ ^- ]]; then
                    ISSUE_KEY="$1"
                else
                    error "Unknown option: $1"
                    show_help_from_manual "branch" || true
                    return 1
                fi
                shift
                ;;
        esac
    done

    if [[ "$SHOW_HELP" == "true" ]]; then
        show_help_from_manual "branch" || true
        return 0
    fi

    if [ -z "$ISSUE_KEY" ]; then
        error "You must provide an issue key (e.g. jira branch PROJ-123)"
        show_help_from_manual "branch" || true
        return 1
    fi
    
    ISSUE_KEY=$(echo "$ISSUE_KEY" | tr '[:lower:]' '[:upper:]')

    local jira_bin="${JIRA_CLI_ROOT:-$DIR/..}/bin/jira"
    [[ -x "$jira_bin" ]] || jira_bin="${DIR}/jira"

    local issue_summary=""
    local issue_type=""
    local issue_priority=""
    local branch_prefix=""
    local branch_name=""

    if [ -z "$BRANCH_SUMMARY" ] || [ -z "$BRANCH_PREFIX" ]; then
        local issue_json=""
        if [ "$DRY_RUN" = false ]; then
            info "Retrieving issue $ISSUE_KEY from JIRA..."
        fi
        issue_json=$("$jira_bin" issue-for-branch "$ISSUE_KEY" 2>/dev/null || true)
        
        if [ -n "$issue_json" ] && printf '%s' "$issue_json" | jq -e '.fields' >/dev/null 2>&1; then
            issue_summary=$(printf '%s' "$issue_json" | jq -r '(.fields.summary // "")')
            issue_type=$(printf '%s' "$issue_json" | jq -r '(.fields.issuetype.name // "")')
            issue_priority=$(printf '%s' "$issue_json" | jq -r '(.fields.priority.name // "")')
            local issue_resolution
            issue_resolution=$(printf '%s' "$issue_json" | jq -r '(.fields.resolution.name // empty)')
            if [ "$DRY_RUN" = false ] && [ -n "$issue_resolution" ]; then
                warning "Ticket $ISSUE_KEY is closed (resolution: $issue_resolution)"
            fi
        fi
    fi

    if [ -n "$BRANCH_SUMMARY" ]; then
        issue_summary="$BRANCH_SUMMARY"
    fi
    if [ -n "$BRANCH_PREFIX" ]; then
        branch_prefix="$BRANCH_PREFIX"
    else
        branch_prefix=$(determine_branch_prefix "$issue_type" "$issue_priority")
    fi
    branch_name=$(build_branch_name "$branch_prefix" "$ISSUE_KEY" "$issue_summary")

    if [ "$DRY_RUN" = true ]; then
        echo "$branch_name"
        return 0
    fi

    if [ "$QUICK_MODE" = true ]; then
        git checkout -b "$branch_name"
        return $?
    fi

    info "Fetching latest changes from remote..."
    git fetch --prune origin 2>/dev/null || warning "Could not fetch from origin. Continuing with local refs."

    if [ "$RENAME_MODE" = true ]; then
        local current_branch
        current_branch=$(git branch --show-current 2>/dev/null || echo "")
        if [ -z "$current_branch" ]; then
            error "Failed to determine current branch"
            return 1
        fi
        info "Renaming current branch '$current_branch' to '$branch_name'..."
        git branch -m "$branch_name"
        success "Branch renamed to: $branch_name"
    else
        local base_ref=""
        if [ "$FRESH_REMOTE_BASE" = true ]; then
            local default_branch
            default_branch=$(get_default_branch)
            if [ -n "$default_branch" ]; then
                base_ref="origin/$default_branch"
            fi
        fi
        
        info "Creating branch '$branch_name'..."
        if [ -n "$base_ref" ] && git rev-parse --verify "$base_ref" >/dev/null 2>&1; then
            git checkout -b "$branch_name" "$base_ref"
        else
            git checkout -b "$branch_name"
        fi
        success "Switched to branch: $branch_name"
    fi
    return 0
}
