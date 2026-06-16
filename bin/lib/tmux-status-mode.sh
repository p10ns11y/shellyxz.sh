#!/usr/bin/env bash
# Shared tmux status-bar mode segments (PREFIX · COPY · INSERT/NORMAL · ZOOM).
# Sourced by tmux-mode-sync.sh — single source of truth for status-right format.
set -euo pipefail

# tmux truncates status-right to status-right-length; mode string needs headroom.
readonly TMUX_STATUS_RIGHT_LENGTH=120

# Style OUTSIDE #{?...} branches — nested #[...] inside conditionals breaks when set via CLI
# (shows literal "bold]" and prints every label). Omarchy uses the same pattern.
tmux_status_mode_segments() {
    printf '%s' \
        '#[fg=colour214,bold]' \
        '#{?client_prefix,PREFIX ,}' \
        '#{?pane_in_mode,COPY ,}' \
        '#{?#{==:#{@editor_mode},insert},INSERT ,}' \
        '#{?#{==:#{@editor_mode},normal},NORMAL ,}' \
        '#{?window_zoomed_flag,ZOOM ,}' \
        '#[default] '
}

tmux_status_mode_workflow_tail() {
    printf '%s' \
        '#[fg=blue]' \
        '#{?#{==:#{@workflow_status},on},#{@workflow_mode} ,}' \
        '#[default]'
}

tmux_status_mode_soc_tail() {
    printf '%s' \
        '#[fg=colour214]#{@verify_risk} #[fg=brightblack]| #{@verify_project_name} | ' \
        '#{?#{==:#{@workflow_mode},verify},ACTIVE,idle} '
}

tmux_status_mode_menu_host_tail() {
    printf '%s' '#[fg=colour240,bold]?#[default] #[fg=brightblack]#h '
}

tmux_status_right_format_workflow() {
    printf '%s%s%s' \
        "$(tmux_status_mode_segments)" \
        "$(tmux_status_mode_workflow_tail)" \
        "$(tmux_status_mode_menu_host_tail)"
}

tmux_status_right_format_soc() {
    printf '%s%s%s' \
        "$(tmux_status_mode_segments)" \
        "$(tmux_status_mode_soc_tail)" \
        "$(tmux_status_mode_menu_host_tail)"
}

tmux_status_mode_apply() {
    local variant="${1:-workflow}"
    tmux set-option -g status-right-length "$TMUX_STATUS_RIGHT_LENGTH"
    case "$variant" in
        soc)
            tmux set-option -g status-right "$(tmux_status_right_format_soc)"
            ;;
        workflow | verify | *)
            tmux set-option -g status-right "$(tmux_status_right_format_workflow)"
            ;;
    esac
}
