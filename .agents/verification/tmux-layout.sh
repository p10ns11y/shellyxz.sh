#!/usr/bin/env bash
# Shell repo verification cockpit — golden-ratio, insight-first layout.
# Usage: tmux-layout.sh [directory]
set -euo pipefail

DIR="${1:-.}"
SCRIPT_NAME="shell-verify-layout"
VERIFY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR" && pwd)"

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
# shellcheck source=/dev/null
source "$HOME/.config/shell/bin/lib/verify-layout.sh"

SESSION="$(tmux display-message -p '#{session_name}')"
ROOT="$(verify_workflow_root "$ROOT")"
verify_set_workflow_dir "$SESSION" "$ROOT" >/dev/null
tmux set-option -t "$SESSION" @workflow_mode verify

verify_apply_theme "$SESSION" "shell" "MEDIUM" "$VERIFY_DIR/tmux-theme.conf"

# CHECK:watch — full first run, then append refreshes (no clear; scroll up for first errors).
CHECK_WATCH_INTERVAL=90
WATCH_CMD="CHECK_WATCH_INTERVAL=${CHECK_WATCH_INTERVAL} ${HOME}/.config/shell/bin/check-shell-watch.sh"
SYNC_CMD="${HOME}/.config/shell/bin/check-template-sync.sh"

if verify_layout_ok "$SESSION"; then
    tmux select-window -t 'verify'
else
    # Pass 1: GIT (lazygit) major left column; ops stack minor right column.
    # Pass 2: SYNC confirm (minor top); CHECK:watch (major center); CMD (minor bottom-right).
    # Omitted: FILES/yazi, SYS/btop — no verification signal for this repo.
    verify_layout_build_golden_grid "$SESSION" "$ROOT" 1
    tmux set-window-option -t verify history-limit 100000

    if command -v lazygit >/dev/null 2>&1; then
        verify_launch_pane 'verify.0' monitor 'GIT' "$ROOT" lazygit
    else
        verify_launch_pane 'verify.0' monitor 'GIT' "$ROOT" "echo 'install lazygit (optional: paru -S lazygit)'"
    fi

    verify_launch_pane 'verify.1' verify 'SYNC' "$ROOT" "$SYNC_CMD"
    verify_launch_pane 'verify.2' watch 'CHECK:watch' "$ROOT" "$WATCH_CMD"
    verify_launch_pane 'verify.3' monitor 'CMD' "$ROOT" ''

    tmux set-option -t "$SESSION" @verify_layout_version golden-4phi

    tmux select-pane -t 'verify.3'
fi

CONSOLE="$(verify_console_target "$SESSION")"
verify_maybe_rescan "$SESSION" "$CONSOLE"
tmux select-pane -t "$CONSOLE"
