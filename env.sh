#!/usr/bin/env sh
# ~/.config/shell/env.sh
# Portable environment variables and PATH setup.
# Sourced by bash, zsh, and (partially) fish.

# Safely add to PATH (deduplicated)
path_add() {
    case ":$PATH:" in
        *":$1:"*) return ;;
        *) [ -d "$1" ] && export PATH="$1:$PATH" ;;
    esac
}

# Highest priority personal bins
path_add "$HOME/.local/bin"
path_add "$HOME/bin"
path_add "$HOME/.local/share/mise/shims"

# Language/tool managers and runtimes
path_add "$HOME/.bun/bin"
path_add "$HOME/.opencode/bin"
path_add "$HOME/.local/share/solana/install/active_release/bin"
path_add "$HOME/.local/share/pnpm"
path_add "$HOME/.cargo/bin"
path_add "$HOME/.risc0/bin"
path_add "$HOME/.grok/bin"

# Mamba (keep later)
path_add "$HOME/mamba/bin"

# pnpm official handling
export PNPM_HOME="$HOME/.local/share/pnpm"
path_add "$PNPM_HOME"

# Performance & misc
export PIP_CACHE_DIR="$HOME/pip-cache"
export TMPDIR="$HOME/tmp"
export OMP_NUM_THREADS=12
export MKL_NUM_THREADS=12
export HSA_OVERRIDE_GFX_VERSION=11.0.0

# Fix clear if mamba interferes
alias clear='/usr/bin/clear' 2>/dev/null || true

# SSH & GPG
export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ssh-agent.socket"
export GPG_TTY="$(tty)"

# Source Omarchy envs early (if available)
if [ -f "$HOME/.local/share/omarchy/default/bash/envs" ]; then
    . "$HOME/.local/share/omarchy/default/bash/envs"
fi

# Your custom loaders (keep if they exist)
[ -f "$HOME/.local/share/../bin/env" ] && . "$HOME/.local/share/../bin/env"
[ -f "$HOME/.vite-plus/env" ] && . "$HOME/.vite-plus/env"
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
