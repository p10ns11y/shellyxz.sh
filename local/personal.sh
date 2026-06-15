#!/usr/bin/env sh
# ~/.config/shell/local/personal.sh
# Work-specific / personal aliases and settings (local overlay).

if [ -f "$HOME/.config/shell/core/lib.sh" ]; then
    # shellcheck disable=SC1091
    . "$HOME/.config/shell/core/lib.sh"
    load_secrets_file "$HOME/.config/secrets/dev.env" 2>/dev/null || true
elif [ -f "$HOME/.config/shell/lib.sh" ]; then
    # shellcheck disable=SC1091
    . "$HOME/.config/shell/lib.sh"
    load_secrets_file "$HOME/.config/secrets/dev.env" 2>/dev/null || true
fi

alias agrepos="cd ~/Work/agents/public-agenc-repos/"
alias agcore="cd ~/Work/agents/public-agenc-repos/agenc-core"
alias agproto="cd ~/Work/agents/public-agenc-repos/agenc-protocol"
