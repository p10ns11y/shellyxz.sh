#!/usr/bin/env sh
# Shim — canonical emitter is discover-tests.sh (SN-8).
# Usage: parse-project-tests-discover.sh ROOT

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/discover-tests.sh"
discover_tests "${1:?root}"
