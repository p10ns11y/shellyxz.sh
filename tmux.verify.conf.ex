# ~/.config/tmux/verify.conf
# Verification workflow overlay — included from ~/.config/tmux/tmux.conf
# Managed by ~/.config/shell/bin/migrate.sh
#
# Key mnemonics (Omarchy prefix = C-Space):
#   Prefix+B  agent build  (ab)  — full-pane agent TUI in `build` window
#   Prefix+V  agent verify (av)  — review cockpit in `verify` window
#   Prefix+?  keymap menu (fzf popup or display-menu) — also click status-right
#   Prefix+Z  zoom pane (tmux built-in; not agent-specific)
# B/V are chosen to match shell aliases; they do not override tmux defaults for
# lower-case b (last window) — these are shifted B and V.

# Workflow labels (set by agent-build / agent-verify layout scripts)
# @workflow_mode is build | verify | empty. @workflow_dir holds the project path.
# Mode bar (PREFIX/COPY/INSERT/NORMAL/ZOOM): tmux.status-mode.conf.ex + tmux-mode-sync.sh
set -g @workflow_status on
set -g @workflow_mode ''

source-file ~/.config/shell/tmux.status-mode.conf.ex

# Keymap helper — Prefix+? or click status-right
bind ? run-shell '~/.config/shell/bin/tmux-keymap-menu.sh'
bind -n MouseDown1StatusRight run-shell '~/.config/shell/bin/tmux-keymap-menu.sh'

# Zoom active pane (Prefix+Z) — ad-hoc full width inside any window
bind Z resize-pane -Z

# Cycle layouts (Prefix+Space) — golden φ on verify window, tmux next-layout elsewhere
bind Space run-shell '~/.config/shell/bin/tmux-cycle-layout.sh'

# Agent build (Prefix+B) — ab / agent_build
bind B run-shell '~/.config/shell/bin/agent-build-layout.sh "#{pane_current_path}"'

# Verification cockpit (Prefix+V) — av / agent_verify
bind V run-shell '~/.config/shell/bin/agent-verify-layout.sh "#{pane_current_path}"'
