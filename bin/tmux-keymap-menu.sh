#!/usr/bin/env bash
# Verification workflow keymap helper — fzf popup or tmux display-menu fallback.
# Usage: tmux-keymap-menu.sh
# Bound: Prefix+? · click status-right (MouseDown1StatusRight)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEYMAP_FILE="${TMUX_KEYMAP_FILE:-$SCRIPT_DIR/data/tmux-keymaps.tsv}"
BUILD="$HOME/.config/shell/bin/agent-build-layout.sh"
VERIFY="$HOME/.config/shell/bin/agent-verify-layout.sh"
TEST="$HOME/.config/shell/bin/agent-test-layout.sh"
CYCLE="$HOME/.config/shell/bin/tmux-cycle-layout.sh"

if [ -z "${TMUX:-}" ]; then
    echo "tmux-keymap-menu: must run inside tmux" >&2
    exit 1
fi

_keymap_pane() {
    printf '%s' "${TMUX_KEYMAP_PANE:-$(tmux display-message -p '#{pane_id}')}"
}

_keymap_path() {
    if [ -n "${TMUX_KEYMAP_PATH:-}" ]; then
        printf '%s' "$TMUX_KEYMAP_PATH"
    else
        tmux display-message -p -t "$(_keymap_pane)" '#{pane_current_path}'
    fi
}

_expand_cmd() {
    local raw="$1"
    local path
    path="$(_keymap_path)"
    raw="${raw//#\{pane_current_path\}/$path}"
    raw="${raw//\"#\{pane_current_path\}\"/$(printf '%q' "$path")}"
    printf '%s' "$raw"
}

_list_entries() {
    grep -v '^#' "$KEYMAP_FILE" 2>/dev/null \
        | grep -v '^[[:space:]]*$' \
        | awk -F'\t' 'NF >= 5 && $1 != "kind" { print }'
}

_tmux_client_cmd() {
    local cmd="$1"
    case "$cmd" in
        next-layout | cycle-layout)
            "$CYCLE"
            ;;
        resize-pane\ -Z)
            tmux resize-pane -t "$(_keymap_pane)" -Z
            ;;
        source-file\ *)
            # shellcheck disable=SC2086
            tmux source-file ${cmd#source-file }
            ;;
        *)
            echo "tmux-keymap-menu: unknown tmux command: $cmd" >&2
            return 1
            ;;
    esac
}

_exec_cmd() {
    local target cmd
    target="$(_keymap_pane)"
    cmd="$(_expand_cmd "$1")"

    case "$cmd" in
        send-keys:*)
            tmux send-keys -t "$target" "${cmd#send-keys:}" Enter
            ;;
        next-layout | cycle-layout | resize-pane\ -Z | source-file\ *)
            _tmux_client_cmd "$cmd"
            ;;
        AGENT_VERIFY_RESCAN=1\ *)
            AGENT_VERIFY_RESCAN=1 tmux run-shell -b "${cmd#AGENT_VERIFY_RESCAN=1 }"
            ;;
        *)
            tmux run-shell -b "$cmd"
            ;;
    esac
}

_parse_pick() {
    awk -F'\t' 'NF >= 5 {
        cmd = $5
        for (i = 6; i <= NF; i++) cmd = cmd "\t" $i
        printf "%s\t%s\t%s\t%s\t%s\n", $1, $2, $3, $4, cmd
    }'
}

_handle_pick() {
    local pick="$1"
    local kind label shortcut menu_action_label cmd

    [ -n "$pick" ] || return 0

    IFS=$'\t' read -r kind label shortcut menu_action_label cmd <<< "$(printf '%s' "$pick" | _parse_pick)"
    [ -n "${kind:-}" ] || return 0

    if [ "$kind" = "run" ]; then
        _exec_cmd "$cmd"
    else
        tmux display-message -d 6000 "$label ($shortcut) [$menu_action_label]: $cmd"
    fi
}

_display_menu() {
    local target path
    target="$(_keymap_pane)"
    path="$(_keymap_path)"

    tmux display-menu -T "Workflow keys (Prefix+?)" -x W -y S \
        "Agent build · Prefix+B" B "run-shell '$BUILD $(printf '%q' "$path")'" \
        "Verify cockpit · Prefix+V" V "run-shell '$VERIFY $(printf '%q' "$path")'" \
        "Test cockpit · Prefix+T" T "run-shell '$TEST $(printf '%q' "$path")'" \
        "Verify + scan" s "run-shell 'AGENT_VERIFY_RESCAN=1 $VERIFY $(printf '%q' "$path")'" \
        "Agent continue · ab -c" c "send-keys -t $target agent_back Enter" \
        "" \
        "agent_scan" a "send-keys -t $target agent_scan Enter" \
        "git diff (delta)" g "send-keys -t $target git diff Enter" \
        "git diff --staged" G "send-keys -t $target git diff --staged Enter" \
        "gdf (difftastic)" d "send-keys -t $target gdf Enter" \
        "vf (fuzzy file)" f "send-keys -t $target vf Enter" \
        "" \
        "Zoom · Prefix+Z" z "run-shell 'tmux resize-pane -t $target -Z'" \
        "Cycle layout · Prefix+Space" l "run-shell '$CYCLE'" \
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

_fzf_inner() {
    local pick_file="$1"
    local pick fzf_status

    set +e
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
    )"
    fzf_status=$?
    set -e

    if [ "$fzf_status" -eq 0 ] && [ -n "$pick" ]; then
        printf '%s' "$pick" >"$pick_file"
    fi
}

_run_fzf_popup() {
    local pick_file popup_status
    pick_file="$(mktemp "${TMPDIR:-/tmp}/tmux-keymap.XXXXXX")"

    TMUX_KEYMAP_PANE="$(tmux display-message -p '#{pane_id}')"
    TMUX_KEYMAP_PATH="$(tmux display-message -p '#{pane_current_path}')"
    export TMUX_KEYMAP_PANE TMUX_KEYMAP_PATH

    set +e
    tmux display-popup -w 72% -h 60% -E \
        "bash $(printf '%q' "$0") --fzf-inner $(printf '%q' "$pick_file")"
    popup_status=$?
    set -e

    if [ -s "$pick_file" ]; then
        _handle_pick "$(<"$pick_file")"
        rm -f "$pick_file"
        return 0
    fi

    rm -f "$pick_file"
    return "$popup_status"
}

_init_caller() {
    TMUX_KEYMAP_PANE="$(tmux display-message -p '#{pane_id}')"
    TMUX_KEYMAP_PATH="$(tmux display-message -p '#{pane_current_path}')"
    export TMUX_KEYMAP_PANE TMUX_KEYMAP_PATH
}

case "${1:-}" in
    --fzf-inner)
        [ -n "${2:-}" ] || { echo "tmux-keymap-menu: missing pick file" >&2; exit 1; }
        _fzf_inner "$2"
        ;;
    --menu)
        _init_caller
        _display_menu
        ;;
    --exec-pick)
        shift
        _init_caller
        _handle_pick "$1"
        ;;
    *)
        _init_caller
        if command -v fzf >/dev/null 2>&1; then
            _run_fzf_popup || _display_menu
        else
            _display_menu
        fi
        ;;
esac
