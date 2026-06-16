#!/usr/bin/env bash
# Agent build layout for tmux — one full-pane window for agent TUIs (grok default).
# Usage: agent-build-layout.sh [directory] [--continue|--no-launch] [-- command...]
set -euo pipefail

SCRIPT_NAME="agent-build-layout"
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

# shellcheck source=/dev/null
source "$HOME/.config/shell/bin/lib/verify-launch.sh"

DIR="$(verify_workflow_root "$DIR")"
SESSION="$(tmux display-message -p '#{session_name}')"
verify_set_workflow_dir "$SESSION" "$DIR" >/dev/null
tmux set-option -t "$SESSION" @workflow_mode build

MODE_SYNC="$HOME/.config/shell/bin/tmux-mode-sync.sh"
if [ -x "$MODE_SYNC" ]; then
    "$MODE_SYNC" apply-workflow
fi

BUILD_EXISTS=false
if tmux list-windows -F '#{window_name}' 2>/dev/null | grep -qx 'build'; then
    BUILD_EXISTS=true
    tmux select-window -t 'build'
elif tmux list-windows -F '#{window_name}' 2>/dev/null | grep -qx 'work'; then
    tmux rename-window -t 'work' 'build'
    BUILD_EXISTS=true
    tmux select-window -t 'build'
else
    tmux new-window -n build -c "$DIR"
    if [ -z "$LAUNCH" ]; then
        LAUNCH="default"
    fi
fi

_build_pane_target() {
    local idx
    idx="$(tmux list-panes -t '=build' -F '#{pane_index}' | head -1)"
    if [ -z "$idx" ]; then
        echo "$SCRIPT_NAME: no pane in build window" >&2
        return 1
    fi
    printf '=build.%s' "$idx"
}

_launch_build_cmd() {
    local target cmd
    target="$(_build_pane_target)" || return 1
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
    continue)
        _launch_build_cmd grok -c
        ;;
    custom)
        _launch_build_cmd "${CMD[@]}"
        ;;
    default)
        if [ "$BUILD_EXISTS" = false ]; then
            _launch_build_cmd
        fi
        ;;
esac

build_target="$(_build_pane_target)" || exit 1
tmux select-pane -t "$build_target"
unset build_target
