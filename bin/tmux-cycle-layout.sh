#!/usr/bin/env bash
# Cycle layout: re-apply golden φ on verify window, else tmux next-layout.
set -euo pipefail

if [ -z "${TMUX:-}" ]; then
    echo "tmux-cycle-layout: must run inside tmux" >&2
    exit 1
fi

SESSION="$(tmux display-message -p '#{session_name}')"
WIN="$(tmux display-message -p '#{window_name}')"

if [ "$WIN" = verify ]; then
    # shellcheck source=/dev/null
    source "${HOME}/.config/shell/bin/lib/verify-layout.sh"
    verify_layout_apply_golden_proportions "$SESSION"
    tmux display-message -d 1500 'verify layout: golden proportions' 2>/dev/null || true
else
    tmux next-layout
fi
