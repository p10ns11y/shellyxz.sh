#!/usr/bin/env sh
# ~/.config/shell/personal.sh
# Work-specific / personal aliases and settings.
# This file is sourced after aliases.sh

# Dev secrets live in ~/.config/secrets/ (outside this git repo).
# Loaded via validated KEY=value parser — never set -a (auto-exports arbitrary assignments).
if [ -f "$HOME/.config/shell/lib.sh" ]; then
    # shellcheck disable=SC1091
    . "$HOME/.config/shell/lib.sh"
    load_secrets_file "$HOME/.config/secrets/dev.env" 2>/dev/null || true
fi

alias agrepos="cd ~/Work/agents/public-agenc-repos/"
alias agcore="cd ~/Work/agents/public-agenc-repos/agenc-core"
alias agproto="cd ~/Work/agents/public-agenc-repos/agenc-protocol"

# Add any other personal/work aliases here in the future
