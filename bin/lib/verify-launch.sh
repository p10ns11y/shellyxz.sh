#!/usr/bin/env bash
# Tiered pane launch helpers for project verification cockpits.
# Sourced by .agents/verification/tmux-layout.sh or called via verify-pane-launch.sh.
set -euo pipefail

VERIFY_LAUNCH_LIB_DIR="${VERIFY_LAUNCH_LIB_DIR:-$HOME/.config/shell/bin/lib}"
VERIFY_PANE_LAUNCH="${VERIFY_PANE_LAUNCH:-$HOME/.config/shell/bin/verify-pane-launch.sh}"

# Pane index base for the verify window (0 by default; may be 1 in user tmux config).
verify_pane_base() {
    local session="${1:?session}"
    local win="${session}:verify"
    tmux show-window-options -gv -t "$win" pane-base-index 2>/dev/null \
        || tmux show-options -gv pane-base-index 2>/dev/null \
        || echo 0
}

# Layout recipes assume pane index 0 — normalize after new-window when session uses pane-base-index 1.
verify_normalize_pane_indexing() {
    local session="${1:?session}"
    tmux set-window-option -t "${session}:verify" pane-base-index 0
}

# True when verify window has golden-4 structure: CMD pane, no placeholder/low-value panes.
verify_layout_ok() {
    local session="${1:?session}"
    local win="${session}:verify"
    local wh git_h git_w ww ver=""

    if ! tmux list-windows -F '#{window_name}' 2>/dev/null | grep -qx 'verify'; then
        return 1
    fi
    if ! tmux list-panes -t "$win" -F '#{pane_title}' 2>/dev/null | grep -qx 'CMD'; then
        return 1
    fi
    if tmux list-panes -t "$win" -F '#{pane_title}' 2>/dev/null | grep -qE '^(FILES|SYS|INSIGHT|VERIFY)$'; then
        return 1
    fi
    ver="$(tmux show-option -gv @verify_layout_version 2>/dev/null || echo '')"
    if [ -n "$ver" ] && [ "$ver" != "golden-4phi" ]; then
        return 1
    fi
    if ! tmux list-panes -t "$win" -F '#{pane_index}' 2>/dev/null | grep -qx '3'; then
        return 0
    fi
    wh="$(tmux display-message -p -t "$win" '#{window_height}')"
    ww="$(tmux display-message -p -t "$win" '#{window_width}')"
    git_h="$(tmux display-message -p -t "${win}.3" '#{pane_height}' 2>/dev/null || echo 0)"
    git_w="$(tmux display-message -p -t "${win}.3" '#{pane_width}' 2>/dev/null || echo 0)"
    if [ "$git_h" -lt $((wh - 1)) ]; then
        return 1
    fi
    if [ "$git_w" -gt $((ww * 42 / 100)) ]; then
        return 1
    fi
    return 0
}

# Resolve console pane for agent_scan / final focus. Prints e.g. Work:verify.0
verify_console_target() {
    local session="${1:?session}"
    local win="${session}:verify"
    local idx=""
    local base

    if ! tmux list-windows -F '#{window_name}' 2>/dev/null | grep -qx 'verify'; then
        echo "verify_console_target: missing verify window" >&2
        return 1
    fi

    idx="$(tmux list-panes -t "$win" -F '#{pane_index} #{pane_title}' 2>/dev/null \
        | awk '$2=="CMD"{print $1; exit}')"
    if [ -n "$idx" ]; then
        printf '%s' "${win}.${idx}"
        return 0
    fi

    base="$(verify_pane_base "$session")"
    if tmux list-panes -t "$win" -F '#{pane_index}' 2>/dev/null | grep -qx "$base"; then
        printf '%s' "${win}.${base}"
        return 0
    fi

    idx="$(tmux list-panes -t "$win" -F '#{pane_index}' 2>/dev/null | sort -n | head -1)"
    if [ -n "$idx" ]; then
        printf '%s' "${win}.${idx}"
        return 0
    fi

    echo "verify_console_target: no panes in verify window" >&2
    return 1
}

# Drop a broken verify window so layout scripts can recreate it.
verify_reset_broken_layout() {
    local session="${1:?session}"
    if tmux list-windows -F '#{window_name}' 2>/dev/null | grep -qx 'verify'; then
        tmux kill-window -t "${session}:verify"
    fi
}

# Walk upward from start_dir for .agents/verification/tmux-layout.sh. Prints repo root.
verify_find_layout_root() {
    local start_dir="${1:?start_dir}"
    local dir
    dir="$(cd "$start_dir" && pwd)"
    while [ "$dir" != "/" ]; do
        if [ -x "$dir/.agents/verification/tmux-layout.sh" ]; then
            printf '%s' "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

# Canonical project root for ab / av / agent_scan — one resolution path for all workflow tools.
# Order: verification layout root (walk up) → git toplevel → absolute start directory.
verify_workflow_root() {
    local start="${1:-.}"
    local dir="" root=""

    if [ "$start" = . ]; then
        dir="$(pwd)"
    elif [ -d "$start" ]; then
        dir="$(cd "$start" && pwd)"
    else
        echo "verify_workflow_root: not a directory: $start" >&2
        return 1
    fi

    if root="$(verify_find_layout_root "$dir")"; then
        printf '%s' "$root"
        return 0
    fi

    if root="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)"; then
        printf '%s' "$root"
        return 0
    fi

    printf '%s' "$dir"
}

# Set @workflow_dir to the canonical root. Prints the path.
verify_set_workflow_dir() {
    local session="${1:?session}"
    local root
    root="$(verify_workflow_root "${2:-.}")"
    tmux set-option -t "$session" @workflow_dir "$root"
    printf '%s' "$root"
}

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
# Second arg optional — resolved via verify_console_target when omitted.
verify_maybe_rescan() {
    local session="${1:?session}"
    local console_target="${2:-}"
    if [ -z "$console_target" ]; then
        console_target="$(verify_console_target "$session")"
    fi
    local rescan=0

    local wf_rescan
    wf_rescan="$(tmux show-option -gv @workflow_rescan 2>/dev/null || echo 0)"
    if [ "$wf_rescan" = "1" ] || [ "${AGENT_VERIFY_RESCAN:-0}" = "1" ]; then
        rescan=1
    fi
    tmux set-option -t "$session" @workflow_rescan 0

    if [ "$rescan" = "1" ]; then
        tmux display-message -d 2500 'agent_scan (av --scan)' 2>/dev/null || true
        tmux send-keys -t "$console_target" 'agent_scan' Enter
    fi
}
