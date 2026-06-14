# ~/.config/tmux/verify.conf
# Verification workflow overlay — included from ~/.config/tmux/tmux.conf
# Managed by ~/.config/shell/bin/migrate.sh

# Zoom active pane (Prefix+Z)
bind Z resize-pane -Z

# Cycle layouts (Prefix+Space) — C-Space is Omarchy prefix; Space is second prefix
bind Space next-layout

# Open verification cockpit (Prefix+V)
bind V run-shell '~/.config/shell/bin/agent-verify-layout.sh "#{pane_current_path}"'
