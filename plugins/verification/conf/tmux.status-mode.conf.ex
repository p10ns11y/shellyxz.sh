# Mode display + hooks — sourced by tmux.verify.conf.ex
# status-right format is applied via tmux-mode-sync.sh (bash; avoids truncation drift).
set -g @editor_mode ''
set -g status-interval 1

set-hook -g pane-focus-out 'run-shell -d 0 "~/.config/shell/bin/tmux-mode-sync.sh pane-focus-out"'
run-shell -d 0 '~/.config/shell/bin/tmux-mode-sync.sh apply workflow'
