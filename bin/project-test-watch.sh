#!/usr/bin/env bash
# Deprecated — use run-project-tests.sh --watch
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/run-project-tests.sh" --watch "$@"
