#!/usr/bin/env bash
# Verification cockpit layout for tmux.
# Usage: agent-verify-layout.sh [directory]
set -euo pipefail

DIR="${1:-.}"
DIR="$(cd "$DIR" && pwd)"
SCRIPT_NAME="agent-verify-layout"

if ! command -v tmux >/dev/null 2>&1; then
    echo "$SCRIPT_NAME: tmux not found" >&2
    exit 1
fi

if [ -z "${TMUX:-}" ]; then
    echo "$SCRIPT_NAME: must run inside tmux" >&2
    exit 1
fi

# Idempotent: reuse existing verify window
if tmux list-windows -F '#{window_name}' 2>/dev/null | grep -qx 'verify'; then
    tmux select-window -t 'verify'
    exit 0
fi

tmux new-window -n verify -c "$DIR"

# Right: lazygit
tmux split-window -h -c "$DIR" -p 38
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
