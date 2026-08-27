#!/bin/bash
DIR="$( cd "$( dirname $(realpath ${BASH_SOURCE[0]} ))" && pwd )";

# Load common library
# shellcheck source=/dev/null
source "$DIR/../lib/common.sh"
source "$DIR/../lib/help_loader.sh"
source "$DIR/../lib/jira.transition.sh"

if [[ "$1" =~ ^(-h|--help|help)$ ]]; then
    show_help_from_manual "transition" || true
    exit 0
fi

# Delegate to transition redo engine
jira_transition_main redo "$@"
exit $?