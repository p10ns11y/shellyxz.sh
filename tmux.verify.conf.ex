# ~/.config/tmux/verify.conf
# Verification workflow overlay — included from ~/.config/tmux/tmux.conf
# Managed by ~/.config/shell/bin/migrate.sh

# Workflow mode in status bar (set by agent-focus / agent-verify layout scripts)
set -g @workflow_mode ''
set -g status-right '#{?client_prefix,PREFIX ,}#{@workflow_mode} #[fg=brightblack]#h '

# Zoom active pane (Prefix+Z) — ad-hoc full width inside any window
bind Z resize-pane -Z

# Cycle layouts (Prefix+Space) — C-Space is Omarchy prefix; Space is second prefix
bind Space next-layout

# Zen agent focus (Prefix+W)
bind W run-shell '~/.config/shell/bin/agent-focus-layout.sh "#{pane_current_path}"'

# Open verification cockpit (Prefix+V)
bind V run-shell '~/.config/shell/bin/agent-verify-layout.sh "#{pane_current_path}"'
