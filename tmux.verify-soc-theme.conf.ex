# SOC-style verification cockpit theme (session-local).
# Applied by project tmux-layout.sh via verify_apply_theme().
# Managed by ~/.config/shell — copy or source from project layouts.

set -g @verify_project_name ''
set -g @verify_risk 'MEDIUM'

# Mission-control status bar (verify mode)
set -g status-left '#[fg=black,bg=colour214,bold] VERIFY #[bg=default] '
set -g status-right '#[fg=colour214]#{@verify_risk} #[fg=brightblack]| #{@verify_project_name} | #{?#{==:#{@workflow_mode},verify},#[fg=colour214]ACTIVE,#[fg=brightblack]idle} #[fg=brightblack]#h '

# Window / pane chrome
set -g window-status-current-format '#[fg=colour214,bold] #I:#W '
set -g pane-border-style 'fg=brightblack'
set -g pane-active-border-style 'fg=colour214'
set -g message-style 'bg=default,fg=colour214'
