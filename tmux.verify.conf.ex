# ~/.config/tmux/verify.conf
# Verification workflow overlay — included from ~/.config/tmux/tmux.conf
# Managed by ~/.config/shell/bin/migrate.sh
#
# Key mnemonics (Omarchy prefix = C-Space):
#   Prefix+B  agent build  (ab)  — full-pane agent TUI in `build` window
#   Prefix+V  agent verify (av)  — review cockpit in `verify` window
#   Prefix+Z  zoom pane (tmux built-in; not agent-specific)
# B/V are chosen to match shell aliases; they do not override tmux defaults for
# lower-case b (last window) — these are shifted B and V.

# Workflow label in status bar (set by agent-build / agent-verify layout scripts)
# @workflow_mode is build | verify | empty. @workflow_dir holds the project path.
set -g @workflow_status on
set -g @workflow_mode ''
set -g status-right '#{?client_prefix,PREFIX ,}#{?#{==:#{@workflow_status},on},#{@workflow_mode} ,}#[fg=brightblack]#h '
# Minimal bar: comment line above and use:
# set -g status-right '#{?client_prefix,PREFIX ,}#[fg=brightblack]#h '

# Zoom active pane (Prefix+Z) — ad-hoc full width inside any window
bind Z resize-pane -Z

# Cycle layouts (Prefix+Space) — C-Space is Omarchy prefix; Space is second prefix
bind Space next-layout

# Agent build (Prefix+B) — ab / agent_build
bind B run-shell '~/.config/shell/bin/agent-build-layout.sh "#{pane_current_path}"'

# Verification cockpit (Prefix+V) — av / agent_verify
bind V run-shell '~/.config/shell/bin/agent-verify-layout.sh "#{pane_current_path}"'
