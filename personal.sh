#!/usr/bin/env sh
# ~/.config/shell/personal.sh
# Work-specific / personal aliases and settings.
# This file is sourced after aliases.sh

# Dev secrets live in ~/.config/secrets/ (outside this git repo)
if [ -f "$HOME/.config/secrets/dev.env" ]; then
    set -a
    . "$HOME/.config/secrets/dev.env"
    set +a
fi

alias agrepos="cd ~/Work/agents/public-agenc-repos/"
alias agcore="cd ~/Work/agents/public-agenc-repos/agenc-core"
alias agproto="cd ~/Work/agents/public-agenc-repos/agenc-protocol"

# Add any other personal/work aliases here in the future
