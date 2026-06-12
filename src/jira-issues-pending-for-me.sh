#!/usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "DEPRECATED: use 'jira issue pending' instead. See: jira issue pending --help" >&2
exec "$DIR/../bin/jira" issue pending "$@"
