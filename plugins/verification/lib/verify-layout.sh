#!/usr/bin/env bash
# Golden-ratio layout helpers for verification cockpits (φ ≈ 1.618 → 62% / 38%).
# Sourced by tmux-layout.sh and agent-verify-layout.sh after verify-launch.sh.
set -euo pipefail

# tmux split-window -p: size of the *new* pane as % of the parent.
readonly VERIFY_LAYOUT_PHI_MAJOR=62
readonly VERIFY_LAYOUT_PHI_MINOR=38

verify_layout_phi_major() { printf '%s' "$VERIFY_LAYOUT_PHI_MAJOR"; }
verify_layout_phi_minor() { printf '%s' "$VERIFY_LAYOUT_PHI_MINOR"; }

# Pass 1 skeleton: git column (major, left) | ops column (minor, right).
verify_layout_split_git_ops() {
    local target="${1:?target}"
    local cwd="${2:-.}"
    tmux split-window -h -t "$target" -c "$cwd" -p "$(verify_layout_phi_minor)"
}

# Pass 2: compact top — original becomes minor height (SYNC / confirm band).
verify_layout_split_minor_top() {
    local target="${1:?target}"
    local cwd="${2:-.}"
    tmux split-window -v -t "$target" -c "$cwd" -p "$(verify_layout_phi_major)"
}

# Pass 2: watch major / CMD minor within the right bottom stack.
verify_layout_split_watch_above_cmd() {
    local target="${1:?target}"
    local cwd="${2:-.}"
    tmux split-window -v -t "$target" -c "$cwd" -p "$(verify_layout_phi_minor)"
}

# Nudge panes to φ proportions after splits (tmux reindexes panes during splits).
verify_layout_apply_golden_proportions() {
    local session="${1:?session}"
    local target="${session}:verify"
    local w h top_h stack_h watch_h cmd_h major_w

    w="$(tmux display-message -p -t "$target" '#{window_width}')"
    h="$(tmux display-message -p -t "$target" '#{window_height}')"

    top_h=$((h * VERIFY_LAYOUT_PHI_MINOR / 100))
    stack_h=$((h - top_h))
    watch_h=$((stack_h * VERIFY_LAYOUT_PHI_MAJOR / 100))
    cmd_h=$((stack_h - watch_h))
    major_w=$((w * VERIFY_LAYOUT_PHI_MAJOR / 100))

    tmux resize-pane -t "${target}.0" -x "$major_w"
    if tmux list-panes -t "$target" -F '#{pane_index}' | grep -qx '3'; then
        tmux resize-pane -t "${target}.1" -y "$top_h"
        tmux resize-pane -t "${target}.2" -y "$watch_h"
        tmux resize-pane -t "${target}.3" -y "$cmd_h"
    else
        tmux resize-pane -t "${target}.1" -y "$top_h"
        tmux resize-pane -t "${target}.2" -y "$stack_h"
    fi
}

# Golden verify grid — pane indices after build (tmux reindexes during splits):
#   4-pane: 0=GIT (full-height left)  1=SYNC/confirm top  2=watch  3=CMD bottom-right
#   3-pane: 0=GIT  1=minor top  2=stack bottom
verify_layout_build_golden_grid() {
    local session="${1:?session}"
    local root="${2:?root}"
    local confirm_split="${3:-1}"

    verify_reset_broken_layout "$session"
    tmux new-window -n verify -c "$root"
    verify_normalize_pane_indexing "$session"

    # Pass 1 — git column (major, left) | ops column (minor, right).
    verify_layout_split_git_ops 'verify' "$root"

    # Pass 2 — SYNC/confirm minor top; right bottom stack for watch + CMD.
    tmux select-pane -t 'verify.1'
    verify_layout_split_minor_top 'verify.1' "$root"

    if [ "$confirm_split" = "1" ]; then
        tmux select-pane -t 'verify.2'
        verify_layout_split_watch_above_cmd 'verify.2' "$root"
    fi

    verify_layout_apply_golden_proportions "$session"
}

# Back-compat aliases (project layouts may reference old names).
verify_layout_split_insight_git() { verify_layout_split_git_ops "$@"; }
verify_layout_split_scroll_above_confirm() { verify_layout_split_watch_above_cmd "$@"; }
