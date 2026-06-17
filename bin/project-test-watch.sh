#!/usr/bin/env bash
# TEST pane: full suite first, then periodic refresh (keeps tmux scrollback).
set -euo pipefail

INTERVAL="${TEST_WATCH_INTERVAL:-60}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$SCRIPT_DIR/check-shell.sh"

run_suite() {
    local t
    for t in "$SCRIPT_DIR"/test/*.test.sh; do
        [ -e "$t" ] || continue
        [ -x "$t" ] || continue
        "$t" || return 1
    done
    "$CHECK" "$@" || true
}

run_suite "$@"
while true; do
    sleep "$INTERVAL"
    printf '\n── project tests %s ──\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    run_suite "$@"
done
