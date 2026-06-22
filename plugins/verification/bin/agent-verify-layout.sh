#!/usr/bin/env bash
# Generic verification cockpit — golden-ratio fallback when no project layout exists.
# Usage: agent-verify-layout.sh [directory] [--generic]
# Delegates to .agents/verification/tmux-layout.sh when present (via verify_workflow_root).
set -euo pipefail

DIR="."
USE_GENERIC=0
SCRIPT_NAME="agent-verify-layout"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --generic)
            USE_GENERIC=1
            shift
            ;;
        *)
            if [ "$DIR" = . ] && { [ "$1" = . ] || [ -d "$1" ]; }; then
                DIR="$1"
                shift
            else
                echo "$SCRIPT_NAME: unknown argument: $1" >&2
                exit 1
            fi
            ;;
    esac
done

if ! command -v tmux >/dev/null 2>&1; then
    echo "$SCRIPT_NAME: tmux not found" >&2
    exit 1
fi

if [ -z "${TMUX:-}" ]; then
    echo "$SCRIPT_NAME: must run inside tmux" >&2
    exit 1
fi

# shellcheck source=/dev/null
verification_plugin_bin="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
verification_plugin_root="$(cd "$verification_plugin_bin/.." && pwd)"
source "$verification_plugin_root/lib/verify-launch.sh"

DIR="$(verify_workflow_root "$DIR")"
SESSION="$(tmux display-message -p '#{session_name}')"
verify_set_workflow_dir "$SESSION" "$DIR" >/dev/null
tmux set-option -t "$SESSION" @workflow_mode verify

PROJECT_LAYOUT="$DIR/.agents/verification/tmux-layout.sh"
if [ "$USE_GENERIC" != 1 ] && [ -x "$PROJECT_LAYOUT" ]; then
    exec "$PROJECT_LAYOUT" "$DIR"
fi

# shellcheck source=/dev/null
source "$verification_plugin_root/lib/verify-layout.sh"

if verify_layout_ok "$SESSION"; then
    tmux select-window -t 'verify'
else
    verify_layout_build_golden_grid "$SESSION" "$DIR" 1

    if command -v lazygit >/dev/null 2>&1; then
        verify_launch_pane 'verify.0' monitor 'GIT' "$DIR" lazygit
    else
        verify_launch_pane 'verify.0' monitor 'GIT' "$DIR" "echo 'install lazygit (optional: paru -S lazygit)'"
    fi

    verify_launch_pane 'verify.1' monitor 'BUILD' "$DIR" ''
    verify_launch_pane 'verify.2' monitor 'WATCH' "$DIR" ''
    verify_launch_pane 'verify.3' monitor 'CMD' "$DIR" ''

    tmux display-message -d 4000 \
        'Generic verify layout — add .agents/verification/tmux-layout.sh (verification-cockpit skill)'

    tmux select-pane -t 'verify.3'
fi

CONSOLE="$(verify_console_target "$SESSION")"
verify_maybe_rescan "$SESSION" "$CONSOLE"
tmux select-pane -t "$CONSOLE"

MODE_SYNC="$verification_plugin_bin/tmux-mode-sync.sh"
if [ -x "$MODE_SYNC" ]; then
    "$MODE_SYNC" apply-workflow
fi
