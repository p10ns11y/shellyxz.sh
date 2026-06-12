#!/usr/bin/env sh
# ~/.config/shell/aliases.sh
# Additional aliases that complement (not duplicate) Omarchy.

# Only add things Omarchy doesn't already handle well

# Better yazi wrapper (cd on exit)
if command -v yazi &>/dev/null; then
    y() {
        local tmp cwd
        tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
        yazi "$@" --cwd-file="$tmp"
        if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
            builtin cd -- "$cwd"
        fi
        rm -f -- "$tmp"
    }
fi

# Monitoring & system
if command -v btop &>/dev/null; then
    alias top='btop'
fi
if command -v duf &>/dev/null; then
    alias df='duf'
fi
if command -v dust &>/dev/null; then
    alias du='dust'
fi

# Quality of life
alias cls='clear'
alias ff='fastfetch'
alias lg='lazygit'
alias n='nvim'

# Git shortcuts (ga is Omarchy's worktree helper — do not alias here)
alias gs='git status'
alias gc='git commit'

# Source personal/work-specific aliases last (so they can override if needed)
if [ -f "$HOME/.config/shell/personal.sh" ]; then
    . "$HOME/.config/shell/personal.sh"
fi
