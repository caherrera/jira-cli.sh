#!/usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "DEPRECATED: use 'jira create' instead. See: jira create --help" >&2
exec "$DIR/../bin/jira" create "$@"
