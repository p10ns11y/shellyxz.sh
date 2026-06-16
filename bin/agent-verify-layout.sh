#!/usr/bin/env bash
# Verification cockpit layout for tmux.
# Usage: agent-verify-layout.sh [directory]
set -euo pipefail

DIR="${1:-.}"
SCRIPT_NAME="agent-verify-layout"

if ! command -v tmux >/dev/null 2>&1; then
    echo "$SCRIPT_NAME: tmux not found" >&2
    exit 1
fi

if [ -z "${TMUX:-}" ]; then
    echo "$SCRIPT_NAME: must run inside tmux" >&2
    exit 1
fi

if [ "$DIR" = . ]; then
    _wf="$(tmux show-option -gv @workflow_dir 2>/dev/null || true)"
    if [ -n "$_wf" ] && [ -d "$_wf" ]; then
        DIR="$_wf"
    fi
    unset _wf
fi
DIR="$(cd "$DIR" && pwd)"

SESSION="$(tmux display-message -p '#{session_name}')"
tmux set-option -t "$SESSION" @workflow_dir "$DIR"
tmux set-option -t "$SESSION" @workflow_mode verify

if tmux list-windows -F '#{window_name}' 2>/dev/null | grep -qx 'verify'; then
    tmux select-window -t 'verify'
else
    tmux new-window -n verify -c "$DIR"

    # Right: lazygit
    tmux split-window -h -c "$DIR" -p 42
    if command -v lazygit >/dev/null 2>&1; then
        tmux send-keys -t 'verify.1' 'lazygit' Enter
    fi

    # Left column bottom: yazi
    tmux select-pane -t 'verify.0'
    tmux split-window -v -c "$DIR" -p 40
    if command -v yazi >/dev/null 2>&1; then
        tmux send-keys -t 'verify.2' 'yazi' Enter
    fi

    # Below yazi: btop
    tmux select-pane -t 'verify.2'
    tmux split-window -v -c "$DIR" -p 35
    if command -v btop >/dev/null 2>&1; then
        tmux send-keys -t 'verify.3' 'btop' Enter
    fi

    tmux select-pane -t 'verify.0'
    tmux select-layout -t verify main-vertical 2>/dev/null || true
fi

RESCAN=0
_wf_rescan="$(tmux show-option -gv @workflow_rescan 2>/dev/null || echo 0)"
if [ "$_wf_rescan" = "1" ] || [ "${AGENT_VERIFY_RESCAN:-0}" = "1" ]; then
    RESCAN=1
fi
unset _wf_rescan
tmux set-option -t "$SESSION" @workflow_rescan 0

if [ "$RESCAN" = "1" ]; then
    tmux display-message -d 2500 'agent_scan (av --scan)' 2>/dev/null || true
    tmux send-keys -t 'verify.0' 'agent_scan .' Enter
fi

tmux select-pane -t 'verify.0'
