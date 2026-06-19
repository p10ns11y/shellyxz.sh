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

# Optional Omarchy desktop overlay (copy local/omarchy.sh.example → local/omarchy.sh)
if [ -f "$HOME/.config/shell/local/omarchy.sh" ]; then
    # shellcheck disable=SC1091
    . "$HOME/.config/shell/local/omarchy.sh"
fi

# Verification cockpit — agent build TUI (plugin; see PLUGIN.md)
export SHELL_AGENT_BUILD_CMD="${SHELL_AGENT_BUILD_CMD:-grok}"
export SHELL_AGENT_BUILD_CONTINUE_CMD="${SHELL_AGENT_BUILD_CONTINUE_CMD:-grok -c}"

# Optional: per-project tmux (ts) — see arch-design/VERIFICATION.md § t vs ts
# alias tw='ts'
