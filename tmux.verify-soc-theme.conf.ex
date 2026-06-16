# SOC-style verification cockpit theme (session-local).
# Applied by project tmux-layout.sh via verify_apply_theme().
# Status-right mode segments: bin/tmux-mode-sync.sh apply soc (after this file loads).

set -g @verify_project_name ''
set -g @verify_risk 'MEDIUM'

# Mission-control status bar (verify mode) — status-right set by tmux-mode-sync.sh
set -g status-left '#[fg=black,bg=colour214,bold] VERIFY #[bg=default] '

# Window / pane chrome
set -g window-status-current-format '#[fg=colour214,bold] #I:#W '
set -g pane-border-style 'fg=brightblack'
set -g pane-active-border-style 'fg=colour214'
set -g message-style 'bg=default,fg=colour214'
