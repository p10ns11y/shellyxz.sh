#!/usr/bin/env bash
# Test cockpit — btop (major left) + project tests (right shell pane).
# Usage: agent-test-layout.sh [directory] [--watch] [--run]
set -euo pipefail

DIR="."
WATCH=0
RUN_ONLY=0
SCRIPT_NAME="agent-test-layout"

# Golden-ratio test layout (matches cockpit.yaml btop-test / phi 62:38).
readonly LAYOUT_PHI_MAJOR=62
readonly LAYOUT_PHI_MINOR=38
readonly LAYOUT_PHI_SLACK=4

while [[ $# -gt 0 ]]; do
    case "$1" in
        --watch)
            WATCH=1
            shift
            ;;
        --run)
            RUN_ONLY=1
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
# shellcheck source=/dev/null
source "$verification_plugin_root/lib/project-tests.sh"

DIR="$(verify_workflow_root "$DIR")"
SESSION="$(tmux display-message -p '#{session_name}')"
WIN="${SESSION}:test"
CREATED=0
TEST_CMD=""

test_layout_ok() {
    local wh ww btop_h btop_w pane_count

    if ! tmux list-windows -F '#{window_name}' 2>/dev/null | grep -qx 'test'; then
        return 1
    fi
    pane_count="$(tmux list-panes -t "$WIN" 2>/dev/null | wc -l | tr -d ' ')"
    if [ "$pane_count" != 2 ]; then
        return 1
    fi
    wh="$(tmux display-message -p -t "$WIN" '#{window_height}')"
    ww="$(tmux display-message -p -t "$WIN" '#{window_width}')"
    btop_h="$(tmux display-message -p -t "${WIN}.0" '#{pane_height}' 2>/dev/null || echo 0)"
    btop_w="$(tmux display-message -p -t "${WIN}.0" '#{pane_width}' 2>/dev/null || echo 0)"
    if [ "$btop_h" -lt $((wh - 1)) ]; then
        return 1
    fi
    if [ "$btop_w" -lt $((ww * (LAYOUT_PHI_MAJOR - LAYOUT_PHI_SLACK) / 100)) ]; then
        return 1
    fi
    return 0
}

test_launch_pane() {
    local target="${1:?target}"
    local title="${2:-}"
    local cmd="${3:-}"

    if [ -n "$title" ]; then
        tmux select-pane -t "$target" -T "$title"
    fi
    if [ -n "$cmd" ]; then
        tmux send-keys -t "$target" "$cmd" Enter
    fi
}

if test_layout_ok; then
    tmux select-window -t 'test'
    if [ "$RUN_ONLY" = 1 ]; then
        if [ "$WATCH" = 1 ]; then
            TEST_CMD="$(project_test_cmd "$DIR" watch)"
        else
            TEST_CMD="$(project_test_cmd "$DIR" once)"
        fi
        tmux send-keys -t "${WIN}.1" C-c 2>/dev/null || true
        test_launch_pane "${WIN}.1" 'TEST' "$TEST_CMD"
        tmux select-pane -t "${WIN}.1"
        tmux display-message -d 2000 'at --run: tests sent to TEST pane' 2>/dev/null || true
        exit 0
    fi
else
    if tmux list-windows -F '#{window_name}' 2>/dev/null | grep -qx 'test'; then
        tmux kill-window -t "$WIN"
    fi
    tmux new-window -n test -c "$DIR"
    tmux set-window-option -t "$WIN" pane-base-index 0
    tmux split-window -h -t "$WIN" -c "$DIR" -p "$LAYOUT_PHI_MINOR"

    w="$(tmux display-message -p -t "$WIN" '#{window_width}')"
    tmux resize-pane -t "${WIN}.0" -x $((w * LAYOUT_PHI_MAJOR / 100))

    if command -v btop >/dev/null 2>&1; then
        test_launch_pane "${WIN}.0" 'BTOP' btop
    else
        test_launch_pane "${WIN}.0" 'BTOP' "echo 'btop not installed (optional: pacman -S btop)'"
    fi

    if [ "$WATCH" = 1 ]; then
        TEST_CMD="$(project_test_cmd "$DIR" watch)"
    else
        TEST_CMD="$(project_test_cmd "$DIR" once)"
    fi
    test_launch_pane "${WIN}.1" 'TEST' "$TEST_CMD"
    CREATED=1
fi

tmux select-pane -t "${WIN}.1"
if [ "$CREATED" = 1 ]; then
    tmux display-message -d 2000 \
        "$([ "$WATCH" = 1 ] && echo 'at: watch mode' || echo 'at: one-shot')" \
        2>/dev/null || true
fi
