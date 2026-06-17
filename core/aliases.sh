#!/usr/bin/env bash
# ~/.config/shell/core/aliases.sh
# Distro-agnostic aliases — preset-specific names documented in environments/README.md.

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

if command -v btop &>/dev/null; then
    alias top='btop'
fi
if command -v duf &>/dev/null; then
    alias df='duf'
fi
if command -v dust &>/dev/null; then
    alias du='dust'
fi

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

alias cls='clear'
alias ff='fastfetch'
alias lg='lazygit'
alias ab='agent_build'
alias af='agent_build'  # legacy — prefer ab (distinct from av)
alias aw='agent_build'  # legacy
alias av='agent_verify'
alias tt='agent_test'
alias shellyhow='$HOME/.config/shell/bin/check-shell.sh'
# n(), ga() may be defined by omarchy layer — do not alias here

alias gs='git status'
alias gc='git commit'
if command -v difft &>/dev/null; then
    alias gdf='git -c diff.external=difft diff'
    alias gdfs='git -c diff.external=difft diff --staged'
fi

# Local overlay last (secrets, work shortcuts)
_personal="$HOME/.config/shell/local/personal.sh"
[ -f "$_personal" ] || _personal="$HOME/.config/shell/personal.sh"
if [ -f "$_personal" ]; then
    # shellcheck disable=SC1091
    . "$_personal"
fi
unset _personal
