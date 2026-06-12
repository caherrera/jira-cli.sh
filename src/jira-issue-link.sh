#!/usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "DEPRECATED: use 'jira issue link' instead. See: jira issue link --help" >&2
exec "$DIR/../bin/jira" issue link "$@"
