#!/usr/bin/env bash
# Apply tmux status-bar mode display + pane-focus hooks.
# Usage: tmux-mode-sync.sh apply [workflow|soc] | pane-focus-out | set-editor MODE
set -euo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
# shellcheck source=/dev/null
source "$LIB_DIR/tmux-status-mode.sh"

if [ -z "${TMUX:-}" ] && [ "${1:-}" != set-editor ]; then
    exit 0
fi

_editor_label() {
    local raw="${1:-}"
    case "$raw" in
        i | insert | INSERT) printf '%s' 'insert' ;;
        n | normal | NORMAL) printf '%s' 'normal' ;;
        *) printf '%s' '' ;;
    esac
}

case "${1:-apply}" in
    apply | apply-verify | apply-workflow)
        tmux_status_mode_apply workflow
        ;;
    apply-soc)
        tmux_status_mode_apply soc
        ;;
    pane-focus-out)
        tmux set-option -g @editor_mode ''
        ;;
    set-editor)
        tmux set-option -g @editor_mode "$(_editor_label "${2:-}")"
        ;;
    *)
        echo "tmux-mode-sync: unknown command: $1" >&2
        exit 1
        ;;
esac
