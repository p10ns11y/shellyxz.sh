#!/usr/bin/env bash
# ~/.config/shell/aliases.sh
# Additional aliases that complement (not duplicate) Omarchy.
# Sourced by bash and zsh rc files; fish loads via bass (bash subshell).

# Only add things Omarchy doesn't already handle well

# Better yazi wrapper (cd on exit)
if command -v yazi &>/dev/null; then
    y() {
        local tmp cwd
        tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
        yazi "$@" --cwd-file="$tmp"
        if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
            builtin cd -- "$cwd" || return 1
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

# Verification speed aliases (guarded — only when binary exists)
if command -v bat &>/dev/null; then
    alias cat='bat --style=plain'
fi
if command -v rg &>/dev/null; then
    alias grep='rg'
fi
if command -v fd &>/dev/null; then
    alias find='fd'
fi
if command -v procs &>/dev/null; then
    alias ps='procs'
fi
if command -v tmux &>/dev/null; then
    alias tt='tmux new-window -n test -c "#{pane_current_path}"'
fi

# Quality of life
alias cls='clear'
alias ff='fastfetch'
alias lg='lazygit'
alias av='agent_verify'
# n() is Omarchy's nvim wrapper — do not alias here (breaks zsh reload)

# Git shortcuts (ga is Omarchy's worktree helper — do not alias here)
alias gs='git status'
alias gc='git commit'
if command -v difft &>/dev/null; then
    alias gdf='git -c diff.external=difft diff'
    alias gdfs='git -c diff.external=difft diff --staged'
fi

# Source personal/work-specific aliases last (so they can override if needed)
if [ -f "$HOME/.config/shell/personal.sh" ]; then
    # shellcheck disable=SC1091
    . "$HOME/.config/shell/personal.sh"
fi
