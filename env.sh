#!/usr/bin/env sh
# ~/.config/shell/env.sh
# Portable environment variables and PATH setup.
# Sourced by bash, zsh, and (partially) fish.

# PATH helpers (deduplicated). With path_prepend, last call wins (highest priority).
path_prepend() {
    case ":$PATH:" in
        *":$1:"*) return ;;
        *) [ -d "$1" ] && export PATH="$1:$PATH" ;;
    esac
}

path_append() {
    case ":$PATH:" in
        *":$1:"*) return ;;
        *) [ -d "$1" ] && export PATH="$PATH:$1" ;;
    esac
}

path_add() { path_prepend "$@"; }

export PNPM_HOME="$HOME/.local/share/pnpm"

# Prepend: lowest priority first → highest priority last
path_prepend "$HOME/.local/share/solana/install/active_release/bin"
path_prepend "$HOME/.opencode/bin"
path_prepend "$HOME/.bun/bin"
path_prepend "$PNPM_HOME"
path_prepend "$HOME/.cargo/bin"
path_prepend "$HOME/.risc0/bin"
path_prepend "$HOME/.grok/bin"
path_prepend "$HOME/.vector/bin"
path_prepend "$HOME/mamba/bin"
path_prepend "$HOME/.local/share/mise/shims"
path_prepend "$HOME/bin"
path_prepend "$HOME/.local/bin"

# Append: fallbacks only (won't shadow bins above)
path_append "$HOME/miniconda/condabin"
path_append "/opt/rocm/bin"

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
