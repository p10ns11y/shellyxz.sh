#!/usr/bin/env bash
# Golden-ratio layout helpers for verification cockpits (φ ≈ 1.618 → 62% / 38%).
# Sourced by tmux-layout.sh and agent-verify-layout.sh after verify-launch.sh.
set -euo pipefail

# tmux split-window -p: size of the *new* pane as % of the parent.
readonly VERIFY_LAYOUT_PHI_MAJOR=62
readonly VERIFY_LAYOUT_PHI_MINOR=38

verify_layout_phi_major() { printf '%s' "$VERIFY_LAYOUT_PHI_MAJOR"; }
verify_layout_phi_minor() { printf '%s' "$VERIFY_LAYOUT_PHI_MINOR"; }

# Pass 1 skeleton: insight column (major, left) | git column (minor, right).
verify_layout_split_insight_git() {
    local target="${1:?target}"
    local cwd="${2:-.}"
    tmux split-window -h -t "$target" -c "$cwd" -p "$(verify_layout_phi_minor)"
}

# Pass 2: compact top — original becomes minor height (CMD, short interactive).
verify_layout_split_minor_top() {
    local target="${1:?target}"
    local cwd="${2:-.}"
    tmux split-window -v -t "$target" -c "$cwd" -p "$(verify_layout_phi_major)"
}

# Pass 2: insight major / confirm minor within the left bottom stack.
verify_layout_split_scroll_above_confirm() {
    local target="${1:?target}"
    local cwd="${2:-.}"
    tmux split-window -v -t "$target" -c "$cwd" -p "$(verify_layout_phi_minor)"
}

# Nudge panes to φ proportions after splits (tmux reindexes panes during splits).
verify_layout_apply_golden_proportions() {
    local session="${1:?session}"
    local target="${session}:verify"
    local w h cmd_h stack_h insight_h confirm_h minor_w

    w="$(tmux display-message -p -t "$target" '#{window_width}')"
    h="$(tmux display-message -p -t "$target" '#{window_height}')"

    cmd_h=$((h * VERIFY_LAYOUT_PHI_MINOR / 100))
    stack_h=$((h - cmd_h))
    insight_h=$((stack_h * VERIFY_LAYOUT_PHI_MAJOR / 100))
    confirm_h=$((stack_h - insight_h))
    minor_w=$((w * VERIFY_LAYOUT_PHI_MINOR / 100))

    tmux resize-pane -t "${target}.0" -y "$cmd_h"
    if tmux list-panes -t "$target" -F '#{pane_index}' | grep -qx '2'; then
        tmux resize-pane -t "${target}.1" -y "$insight_h"
        tmux resize-pane -t "${target}.2" -y "$confirm_h"
        tmux resize-pane -t "${target}.3" -x "$minor_w"
    else
        tmux resize-pane -t "${target}.1" -y "$stack_h"
        tmux resize-pane -t "${target}.2" -x "$minor_w"
    fi
}

# Golden verify grid — pane indices after build (tmux reindexes during splits):
#   4-pane: 0=CMD  1=insight (watch)  2=confirm  3=GIT (full-height right)
#   3-pane: 0=CMD  1=insight          2=GIT
verify_layout_build_golden_grid() {
    local session="${1:?session}"
    local root="${2:?root}"
    local confirm_split="${3:-1}"

    verify_reset_broken_layout "$session"
    tmux new-window -n verify -c "$root"
    verify_normalize_pane_indexing "$session"

    # Pass 1 — insight column (major) | git column (minor).
    verify_layout_split_insight_git 'verify' "$root"

    # Pass 2 — CMD minor top; left bottom stack for insight (+ optional confirm).
    tmux select-pane -t 'verify.0'
    verify_layout_split_minor_top 'verify.0' "$root"

    if [ "$confirm_split" = "1" ]; then
        # Split left bottom stack (pane 1 after reindex), not pane 2 (that is GIT).
        tmux select-pane -t 'verify.1'
        verify_layout_split_scroll_above_confirm 'verify.1' "$root"
    fi

    verify_layout_apply_golden_proportions "$session"
}
