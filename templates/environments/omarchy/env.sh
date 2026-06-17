#!/usr/bin/env sh
# ~/.config/shell/environments/omarchy/env.sh
# Omarchy exports — PATH entries owned by core/path.contract (environment phase).

export OMARCHY_PATH="${OMARCHY_PATH:-$HOME/.local/share/omarchy}"
export OMARCHY_ROOT="${OMARCHY_ROOT:-$OMARCHY_PATH}"

[ -n "${EDITOR:-}" ] && export SUDO_EDITOR="$EDITOR"
export BAT_THEME=ansi
export MANROFFOPT="-c"
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
