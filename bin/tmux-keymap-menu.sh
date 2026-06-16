#!/usr/bin/env bash
# Verification workflow keymap helper — fzf popup or tmux display-menu fallback.
# Usage: tmux-keymap-menu.sh
# Bound: Prefix+? · click status-right (MouseDown1StatusRight)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEYMAP_FILE="${TMUX_KEYMAP_FILE:-$SCRIPT_DIR/data/tmux-keymaps.tsv}"
BUILD="$HOME/.config/shell/bin/agent-build-layout.sh"
VERIFY="$HOME/.config/shell/bin/agent-verify-layout.sh"

if [ -z "${TMUX:-}" ]; then
    echo "tmux-keymap-menu: must run inside tmux" >&2
    exit 1
fi

_list_entries() {
    grep -v '^#' "$KEYMAP_FILE" 2>/dev/null \
        | grep -v '^[[:space:]]*$' \
        | awk -F'\t' 'NF >= 5 && $1 != "kind" { print }'
}

_exec_cmd() {
    local cmd="$1"
    case "$cmd" in
        send-keys:*)
            tmux send-keys -t "#{pane_id}" "${cmd#send-keys:}" Enter
            ;;
        resize-pane\ * | next-layout | source-file\ *)
            tmux command "$cmd"
            ;;
        AGENT_VERIFY_RESCAN=1\ *)
            AGENT_VERIFY_RESCAN=1 tmux run-shell "${cmd#AGENT_VERIFY_RESCAN=1 }"
            ;;
        *)
            tmux run-shell "$cmd"
            ;;
    esac
}

_display_menu() {
    tmux display-menu -T "Workflow keys (Prefix+?)" -x W -y S \
        "Agent build · Prefix+B" b "run-shell '$BUILD \"#{pane_current_path}\"'" \
        "Verify cockpit · Prefix+V" v "run-shell '$VERIFY \"#{pane_current_path}\"'" \
        "Verify + scan" s "run-shell 'AGENT_VERIFY_RESCAN=1 $VERIFY \"#{pane_current_path}\"'" \
        "Agent continue · ab -c" c "send-keys -t #{pane_id} agent_back Enter" \
        "" \
        "agent_scan" a "send-keys -t #{pane_id} agent_scan Enter" \
        "gdf (difftastic)" d "send-keys -t #{pane_id} gdf Enter" \
        "vf (fuzzy file)" f "send-keys -t #{pane_id} vf Enter" \
        "" \
        "Zoom · Prefix+Z" z "resize-pane -Z" \
        "Cycle layout · Prefix+Space" l "next-layout" \
        "Reload tmux · Prefix+q" q "source-file ~/.config/tmux/tmux.conf" \
        "" \
        "Nvim keys (leader)" n "display-message -d 6000 'va=verify grep · vf=find files · vh=harpoon pin · ht=harpoon menu · sg=live_grep'"
}

_fzf_rows() {
    awk -F'\t' '{
        action = ($1 == "run") ? "run" : "view"
        printf "%s\t%s\t%s\t%s\t%s\n", $1, $3, $4, action, $5
    }'
}

_fzf_popup() {
    local pick kind label shortcut action cmd
    pick="$(
        _list_entries \
            | _fzf_rows \
            | fzf \
                --delimiter $'\t' \
                --with-nth 2,3,4 \
                --nth 2,3,4 \
                --header 'label · shortcut · action   |   Enter: run/view · Esc: close' \
                --height 90% \
                --layout reverse \
                --border rounded \
                --prompt 'Keys> '
    )" || return 0

    IFS=$'\t' read -r kind label shortcut action cmd <<< "$pick"
    if [ "$kind" = "run" ]; then
        _exec_cmd "$cmd"
    else
        tmux display-message -d 6000 "$label ($shortcut): $cmd"
    fi
}

case "${1:-}" in
    --fzf-inner)
        _fzf_popup
        ;;
    *)
        if command -v fzf >/dev/null 2>&1; then
            tmux display-popup -w 72% -h 60% -E "bash $(printf '%q' "$0") --fzf-inner"
        else
            _display_menu
        fi
        ;;
esac
