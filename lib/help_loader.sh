#!/bin/bash

# Help loader for jira CLI - loads manual pages from man/ directory

show_help_from_manual() {
    local command="$1"
    local base_dir="${JIRA_CLI_ROOT:-$DIR/..}"
    local manual_file="$base_dir/man/jira-${command}.md"
    
    # Handle command aliases
    case "$command" in
        "user"|"users")
            manual_file="$base_dir/man/jira-user.md"
            ;;
        "project"|"projects")
            manual_file="$base_dir/man/jira-project.md"
            ;;
        "issue"|"issues")
            manual_file="$base_dir/man/jira-issue.md"
            ;;
        "branch"|"branches")
            manual_file="$base_dir/man/jira-branch.md"
            ;;
        "comment"|"comments")
            manual_file="$base_dir/man/jira-comment.md"
            ;;
        "transition"|"transitions"|"done"|"redo")
            manual_file="$base_dir/man/jira-transition.md"
            ;;
        "attach"|"attachment"|"attachments")
            manual_file="$base_dir/man/jira-attach.md"
            ;;
        "link"|"links"|"link-url"|"remote-links")
            manual_file="$base_dir/man/jira-link.md"
            ;;
        "worklog"|"worklogs"|"log")
            manual_file="$base_dir/man/jira-worklog.md"
            ;;
        "edit"|"modify")
            manual_file="$base_dir/man/jira-edit.md"
            ;;
        "board"|"boards"|"sprint"|"sprints"|"agile")
            manual_file="$base_dir/man/jira-agile.md"
            ;;
        "create")
            manual_file="$base_dir/man/jira-create.md"
            ;;
        "search")
            manual_file="$base_dir/man/jira-search.md"
            ;;
        "api")
            manual_file="$base_dir/man/jira-api.md"
            ;;
        "priority"|"priorities")
            manual_file="$base_dir/man/jira-priority.md"
            ;;
        "status"|"statuses")
            manual_file="$base_dir/man/jira-status.md"
            ;;
        "workflow"|"workflows")
            manual_file="$base_dir/man/jira-workflow.md"
            ;;
        "profile"|"myself")
            manual_file="$base_dir/man/jira-profile.md"
            ;;
        "issuetype"|"issuetypes")
            manual_file="$base_dir/man/jira-issuetype.md"
            ;;
        *)
            if [[ -f "$base_dir/man/jira-${command}.md" ]]; then
                manual_file="$base_dir/man/jira-${command}.md"
            else
                return 1
            fi
            ;;
    esac
    
    # Check if manual file exists
    if [[ ! -f "$manual_file" ]]; then
        return 1
    fi
    
    # Load color functions if present
    if [[ -f "$base_dir/vendor/helpers.sh" ]]; then
        # shellcheck source=/dev/null
        source "$base_dir/vendor/helpers.sh"
    fi
    
    # Display the manual file
    cat "$manual_file"
    return 0
}
