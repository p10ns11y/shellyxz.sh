#!/usr/bin/env bash
# Zen focus layout for tmux — single full-pane window for agent TUIs (grok, etc.).
# Usage: agent-focus-layout.sh [directory] [--continue|--no-launch] [-- command...]
set -euo pipefail

SCRIPT_NAME="agent-focus-layout"
DIR="."
LAUNCH="" # unset | default | continue | no | custom
CMD=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c | --continue)
            LAUNCH="continue"
            shift
            ;;
        --no-launch)
            LAUNCH="no"
            shift
            ;;
        --)
            shift
            LAUNCH="custom"
            CMD=("$@")
            break
            ;;
        *)
            if [[ -z "${_dir_set:-}" && ( "$1" == . || -d "$1" ) ]]; then
                DIR="$1"
                _dir_set=1
                shift
            else
                LAUNCH="custom"
                CMD=("$@")
                break
            fi
            ;;
    esac
done

DIR="$(cd "$DIR" && pwd)"

if ! command -v tmux >/dev/null 2>&1; then
    echo "$SCRIPT_NAME: tmux not found" >&2
    exit 1
fi

if [ -z "${TMUX:-}" ]; then
    echo "$SCRIPT_NAME: must run inside tmux" >&2
    exit 1
fi

SESSION="$(tmux display-message -p '#{session_name}')"
tmux set-option -t "$SESSION" @workflow_dir "$DIR"
tmux set-option -t "$SESSION" @workflow_mode work

WORK_EXISTS=false
if tmux list-windows -F '#{window_name}' 2>/dev/null | grep -qx 'work'; then
    WORK_EXISTS=true
    tmux select-window -t 'work'
else
    tmux new-window -n work -c "$DIR"
    if [ -z "$LAUNCH" ]; then
        LAUNCH="default"
    fi
fi

# Resolve first pane in work window (pane-base-index may be 0 or 1).
_work_pane_target() {
    local idx
    idx="$(tmux list-panes -t '=work' -F '#{pane_index}' | head -1)"
    if [ -z "$idx" ]; then
        echo "$SCRIPT_NAME: no pane in work window" >&2
        return 1
    fi
    printf '=work.%s' "$idx"
}

_launch_work_cmd() {
    local target cmd
    target="$(_work_pane_target)" || return 1
    if [ "$#" -eq 0 ]; then
        cmd='grok'
    else
        cmd=$(printf '%s ' "$@")
        cmd=${cmd% }
    fi
    tmux send-keys -t "$target" -l "$cmd"
    tmux send-keys -t "$target" Enter
}

case "$LAUNCH" in
    no | '')
        ;;
    "continue")
        _launch_work_cmd grok -c
        ;;
    custom)
        _launch_work_cmd "${CMD[@]}"
        ;;
    default)
        if [ "$WORK_EXISTS" = false ]; then
            _launch_work_cmd
        fi
        ;;
esac

work_target="$( _work_pane_target )" || exit 1
tmux select-pane -t "$work_target"
unset work_target
