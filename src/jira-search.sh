#!/usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "DEPRECATED: use 'jira search' instead. See: jira search --help" >&2
exec "$DIR/../bin/jira" search "$@"
