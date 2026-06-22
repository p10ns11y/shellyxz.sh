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
    verification_plugin_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    # shellcheck source=/dev/null
    source "$verification_plugin_root/lib/verify-layout.sh"
    verify_layout_apply_golden_proportions "$SESSION"
    tmux display-message -d 1500 'verify layout: golden proportions' 2>/dev/null || true
else
    tmux next-layout
fi
