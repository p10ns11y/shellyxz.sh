# ~/.config/tmux/verify.conf
# Verification workflow overlay — included from ~/.config/tmux/tmux.conf
# Managed by ~/.config/shell/bin/migrate.sh
#
# INSTALL / REFRESH (not sourced in zsh — tmux loads this file):
#   ~/.config/shell/bin/sync-tmux-verify.sh
#   then inside tmux: Prefix+q  (Ctrl+Space, then q)
#
# Omarchy prefix = Ctrl+Space (prefix2 = Ctrl+b).
#
# WORKFLOW KEYS — SHIFTED letters (match shell aliases ab / av / at):
#   Prefix+B   agent build   — Shift+b  (lowercase b is NOT bound here)
#   Prefix+V   verify cockpit — Shift+v  (lowercase v = vertical split, unchanged)
#   Prefix+T   test cockpit   — Shift+t
#   Prefix+?   keymap menu (or click status-right)
#   Prefix+Z   zoom pane
#   Prefix+Space  cycle layout
#
# SPLITS (Omarchy defaults in tmux.conf — do not change):
#   Prefix+h   split horizontal (pane below)
#   Prefix+v   split vertical (pane right)

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

# Test cockpit (Prefix+T) — at / agent_test
bind T run-shell '~/.config/shell/bin/agent-test-layout.sh "#{pane_current_path}"'
