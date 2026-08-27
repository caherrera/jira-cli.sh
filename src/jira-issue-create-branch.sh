#!/bin/bash
DIR="$( cd "$( dirname $(realpath ${BASH_SOURCE[0]} ))" && pwd )";

# Load common library and branch module
# shellcheck source=/dev/null
source "$DIR/../lib/common.sh"
source "$DIR/../lib/help_loader.sh"
source "$DIR/../lib/jira.branch.sh"

jira_branch_main "$@"
exit $?
