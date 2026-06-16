#!/usr/bin/env bash
# Tiered pane launch helpers for project verification cockpits.
# Sourced by .agents/verification/tmux-layout.sh or called via verify-pane-launch.sh.
set -euo pipefail

VERIFY_LAUNCH_LIB_DIR="${VERIFY_LAUNCH_LIB_DIR:-$HOME/.config/shell/bin/lib}"
VERIFY_PANE_LAUNCH="${VERIFY_PANE_LAUNCH:-$HOME/.config/shell/bin/verify-pane-launch.sh}"

# Apply SOC theme vars on the tmux session.
verify_apply_theme() {
    local session="${1:?session}"
    local project="${2:-}"
    local risk="${3:-medium}"
    local soc_ex="${HOME}/.config/shell/tmux.verify-soc-theme.conf.ex"
    local project_theme="${4:-}"

    tmux set-option -t "$session" @verify_project_name "$project"
    tmux set-option -t "$session" @verify_risk "$risk"

    if [ -f "$soc_ex" ]; then
        tmux source-file "$soc_ex"
    fi
    if [ -n "$project_theme" ] && [ -f "$project_theme" ]; then
        tmux source-file "$project_theme"
    fi
}

# Launch a command in a tmux pane according to risk tier.
# Usage: verify_launch_pane TARGET TIER TITLE CWD COMMAND
verify_launch_pane() {
    local target="${1:?target}"
    local tier="${2:?tier}"
    local title="${3:-}"
    local cwd="${4:-.}"
    local cmd="${5:-}"

    if [ -n "$title" ]; then
        tmux select-pane -t "$target" -T "$title"
    fi

    if [ -z "$cmd" ]; then
        tmux send-keys -t "$target" "cd $(printf '%q' "$cwd")" Enter
        return 0
    fi

    case "$tier" in
        monitor | watch)
            tmux send-keys -t "$target" "cd $(printf '%q' "$cwd") && $cmd" Enter
            ;;
        verify)
            tmux send-keys -t "$target" \
                "cd $(printf '%q' "$cwd") && $(printf '%q' "$VERIFY_PANE_LAUNCH") verify $(printf '%q' "$cmd")" \
                Enter
            ;;
        mutate)
            if [ "${AGENT_VERIFY_LAUNCH_MUTATE:-0}" = "1" ]; then
                tmux send-keys -t "$target" \
                    "cd $(printf '%q' "$cwd") && $(printf '%q' "$VERIFY_PANE_LAUNCH") mutate $(printf '%q' "$cmd")" \
                    Enter
            else
                tmux send-keys -t "$target" \
                    "cd $(printf '%q' "$cwd") && echo '[BLOCKED] mutate tier — blocked by default. Use: av --launch-mutate'" \
                    Enter
            fi
            ;;
        *)
            echo "verify_launch_pane: unknown tier: $tier" >&2
            return 1
            ;;
    esac
}

# Run agent_scan in the console pane when rescan is requested.
verify_maybe_rescan() {
    local session="${1:?session}"
    local console_target="${2:?console}"
    local rescan=0

    local wf_rescan
    wf_rescan="$(tmux show-option -gv @workflow_rescan 2>/dev/null || echo 0)"
    if [ "$wf_rescan" = "1" ] || [ "${AGENT_VERIFY_RESCAN:-0}" = "1" ]; then
        rescan=1
    fi
    tmux set-option -t "$session" @workflow_rescan 0

    if [ "$rescan" = "1" ]; then
        tmux display-message -d 2500 'agent_scan (av --scan)' 2>/dev/null || true
        tmux send-keys -t "$console_target" 'agent_scan .' Enter
    fi
}
