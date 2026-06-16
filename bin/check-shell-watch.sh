#!/usr/bin/env bash
# CHECK pane: full shellyhow first, then periodic refresh without clearing the screen.
# watch(1) clears each cycle and truncates in short panes — this keeps tmux scrollback.
# Usage: check-shell-watch.sh [--audit]
set -euo pipefail

INTERVAL="${CHECK_WATCH_INTERVAL:-90}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$SCRIPT_DIR/check-shell.sh"

run_check() {
    "$CHECK" "$@" || true
}

run_check "$@"
while true; do
    sleep "$INTERVAL"
    printf '\n── shellyhow %s ──\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    run_check "$@"
done
