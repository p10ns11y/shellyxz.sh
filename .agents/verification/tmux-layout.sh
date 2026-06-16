#!/usr/bin/env bash
# Shell repo verification cockpit — dogfood / stress test for verification-cockpit skill.
# Usage: tmux-layout.sh [directory]
set -euo pipefail

DIR="${1:-.}"
SCRIPT_NAME="shell-verify-layout"
VERIFY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR" && pwd)"

if ! command -v tmux >/dev/null 2>&1; then
    echo "$SCRIPT_NAME: tmux not found" >&2
    exit 1
fi

if [ -z "${TMUX:-}" ]; then
    echo "$SCRIPT_NAME: must run inside tmux" >&2
    exit 1
fi

# shellcheck source=/dev/null
source "$HOME/.config/shell/bin/lib/verify-launch.sh"

SESSION="$(tmux display-message -p '#{session_name}')"
tmux set-option -t "$SESSION" @workflow_dir "$ROOT"
tmux set-option -t "$SESSION" @workflow_mode verify

verify_apply_theme "$SESSION" "shell" "MEDIUM" "$VERIFY_DIR/tmux-theme.conf"

WATCH_CMD='watch -n 15 -c ~/.config/shell/bin/check-shell.sh'
if ! command -v watch >/dev/null 2>&1; then
    WATCH_CMD='while true; do clear; ~/.config/shell/bin/check-shell.sh; sleep 15; done'
fi

if tmux list-windows -F '#{window_name}' 2>/dev/null | grep -qx 'verify'; then
    tmux select-window -t 'verify'
else
    tmux new-window -n verify -c "$ROOT"

    tmux split-window -h -t 'verify' -c "$ROOT" -p 42
    if command -v lazygit >/dev/null 2>&1; then
        verify_launch_pane 'verify.1' monitor 'GIT' "$ROOT" lazygit
    fi

    tmux select-pane -t 'verify.0'
    tmux split-window -v -t 'verify.0' -c "$ROOT" -p 45
    verify_launch_pane 'verify.2' watch 'CHECK:watch' "$ROOT" "$WATCH_CMD"

    tmux select-pane -t 'verify.2'
    tmux split-window -h -t 'verify.2' -c "$ROOT" -p 50
    verify_launch_pane 'verify.3' verify 'SYNC' "$ROOT" '~/.config/shell/bin/check-template-sync.sh'

    tmux select-pane -t 'verify.2'
    tmux split-window -v -t 'verify.2' -c "$ROOT" -p 40
    if command -v yazi >/dev/null 2>&1; then
        verify_launch_pane 'verify.4' monitor 'FILES' "$ROOT" yazi
    fi

    tmux select-pane -t 'verify.4'
    tmux split-window -v -t 'verify.4' -c "$ROOT" -p 35
    if command -v btop >/dev/null 2>&1; then
        verify_launch_pane 'verify.5' monitor 'SYS' "$ROOT" btop
    fi

    verify_launch_pane 'verify.0' monitor 'CMD' "$ROOT" ''

    tmux select-pane -t 'verify.0'
    tmux select-layout -t verify main-vertical 2>/dev/null || true
fi

verify_maybe_rescan "$SESSION" 'verify.0'
tmux select-pane -t 'verify.0'
