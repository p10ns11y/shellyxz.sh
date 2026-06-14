#!/usr/bin/env sh
# ~/.config/shell/env.sh
# Portable environment variables and PATH setup.
# Sourced by bash, zsh, and (partially) fish.

# Shared safe loaders (Omarchy paths, permission checks, secrets helper)
if [ -f "$HOME/.config/shell/lib.sh" ]; then
    # shellcheck disable=SC1091
    . "$HOME/.config/shell/lib.sh"
fi

# Optional: set SHELL_TRUTH_SEEKER=0 before sourcing to keep inherited $SHELL.
# See shell.md — echo $SHELL is often stale; this overwrites it with the live interpreter.
shell_truth_seeker 2>/dev/null || true

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

# Mamba/conda: let Starship show env; avoid duplicate (xai_exp) prefix on its own line
export CONDA_CHANGEPS1=false

# fzf — bat preview for verification sweeps (skip heavy preview in editor terminals)
if command -v fzf >/dev/null 2>&1; then
    detect_editor_terminal 2>/dev/null || true
    if [ "${SHELL_IN_EDITOR_TERMINAL:-no}" = no ] && command -v bat >/dev/null 2>&1; then
        # shellcheck disable=SC2089,SC2090
        export FZF_DEFAULT_OPTS="--height 50% --layout=reverse --border rounded --preview-window=right:60%:wrap --preview '${HOME}/.config/shell/bin/fzf-preview.sh {}'"
        export FZF_CTRL_T_OPTS='--preview-window=right:60%:wrap'
    else
        # shellcheck disable=SC2090
        export FZF_DEFAULT_OPTS='--height 50% --layout=reverse --border rounded'
    fi
    if command -v fd >/dev/null 2>&1; then
        export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    fi
fi

# Performance & misc
export PIP_CACHE_DIR="$HOME/pip-cache"
export TMPDIR="$HOME/tmp"
export OMP_NUM_THREADS=12
export MKL_NUM_THREADS=12
export HSA_OVERRIDE_GFX_VERSION=11.0.0

# Fix clear if mamba interferes
alias clear='/usr/bin/clear' 2>/dev/null || true

# SSH & GPG — interactive only (avoid tty/socket noise in scripts and CI)
if _is_interactive_session 2>/dev/null; then
    _sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ssh-agent.socket"
    [ -S "$_sock" ] && export SSH_AUTH_SOCK="$_sock"
    _tty=$(tty 2>/dev/null) && [ -n "$_tty" ] && export GPG_TTY="$_tty"
    unset _sock _tty
fi

# Omarchy envs (optional — missing install is fine)
if command -v source_omarchy >/dev/null 2>&1; then
    source_omarchy envs 2>/dev/null || true
elif [ -f "$HOME/.local/share/omarchy/default/bash/envs" ]; then
    # shellcheck disable=SC1091
    . "$HOME/.local/share/omarchy/default/bash/envs"
fi

# External loaders — explicit paths, permission-checked when lib.sh is present
# ~/.local/bin/env — user-managed PATH/tool hooks (not $HOME/.local/share/../bin)
if command -v source_if_safe >/dev/null 2>&1; then
    source_if_safe "$HOME/.local/bin/env" 2>/dev/null || true
    source_if_safe "$HOME/.vite-plus/env" 2>/dev/null || true
    source_if_safe "$HOME/.cargo/env" 2>/dev/null || true
else
    [ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"
    [ -f "$HOME/.vite-plus/env" ] && . "$HOME/.vite-plus/env"
    [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
fi
