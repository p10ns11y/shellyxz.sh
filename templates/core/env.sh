#!/usr/bin/env sh
# ~/.config/shell/core/env.sh
# Distro-agnostic PATH, exports, and environment presets.

SHELL_ROOT="${SHELL_ROOT:-$HOME/.config/shell}"

# shellcheck disable=SC1091
. "$SHELL_ROOT/core/lib.sh"
# shellcheck disable=SC1091
. "$SHELL_ROOT/core/path.sh"

shell_truth_seeker 2>/dev/null || true

# zprofile + zshrc both source env.sh — second pass is a no-op for PATH.
if [ -n "${_SHELL_ENV_SH_LOADED:-}" ]; then
    resolve_shell_environment
    return 0 2>/dev/null || true
fi
export _SHELL_ENV_SH_LOADED=1

export PNPM_HOME="$HOME/.local/share/pnpm"

# Drop known broken inherited segments before building (not a global dedupe pass)
path_drop "/condabin"
path_drop "$HOME/.local/share/../bin"

# Environment exports + preset PATH entries (omarchy, generic, …)
source_environments

# Core PATH — lowest priority first → highest priority last (last prepend wins)
path_prepend "$HOME/.local/share/solana/install/active_release/bin"
path_prepend "$HOME/.opencode/bin"
path_prepend "$HOME/.bun/bin"
path_prepend "$PNPM_HOME"
path_prepend "$HOME/.cargo/bin"
path_prepend "$HOME/.risc0/bin"
path_prepend "$HOME/.grok/bin"
path_prepend "$HOME/.vector/bin"
path_prepend "$HOME/mamba/bin"
path_prepend "$HOME/.vite-plus/bin"
path_prepend "$HOME/.local/share/mise/shims"
path_prepend "$HOME/.local/bin"
path_prepend "$HOME/bin"

path_append "$HOME/miniconda/condabin"
path_append "/opt/rocm/bin"

export CONDA_CHANGEPS1=false

if command -v fzf >/dev/null 2>&1; then
    detect_editor_terminal 2>/dev/null || true
    if [ "${SHELL_IN_EDITOR_TERMINAL:-no}" = no ] && command -v bat >/dev/null 2>&1; then
        _fzf_preview="${HOME}/.config/shell/bin/fzf-preview.sh"
        # shellcheck disable=SC2089,SC2090
        export FZF_DEFAULT_OPTS='--height 50% --layout=reverse --border rounded'
        export FZF_CTRL_T_OPTS="--preview-window=right:60%:wrap --preview '${_fzf_preview} {}'"
        export FZF_CTRL_R_OPTS="--preview-window=down:5:wrap --preview '${_fzf_preview} {}'"
    else
        # shellcheck disable=SC2090
        export FZF_DEFAULT_OPTS='--height 50% --layout=reverse --border rounded'
    fi
    if command -v fd >/dev/null 2>&1; then
        export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    fi
fi

export PIP_CACHE_DIR="$HOME/pip-cache"
export TMPDIR="$HOME/tmp"
export OMP_NUM_THREADS=12
export MKL_NUM_THREADS=12
export HSA_OVERRIDE_GFX_VERSION=11.0.0

alias clear='/usr/bin/clear' 2>/dev/null || true

if _is_interactive_session 2>/dev/null; then
    _sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ssh-agent.socket"
    [ -S "$_sock" ] && export SSH_AUTH_SOCK="$_sock"
    _tty=$(tty 2>/dev/null) && [ -n "$_tty" ] && export GPG_TTY="$_tty"
    unset _sock _tty
fi

# Vite+ shell integration (vp function, completions) — PATH owned above.
if command -v source_if_safe >/dev/null 2>&1; then
    source_if_safe "$HOME/.vite-plus/env" 2>/dev/null || true
else
    [ -f "$HOME/.vite-plus/env" ] && . "$HOME/.vite-plus/env"
fi

# vite-plus/env re-promotes its bin; re-assert user tool priority explicitly
path_prepend "$HOME/bin"

# Rare machine-specific PATH/export tweaks (see local/overwrite.sh.example)
if [ -f "$SHELL_ROOT/local/overwrite.sh" ]; then
    # shellcheck disable=SC1091
    . "$SHELL_ROOT/local/overwrite.sh"
fi

# Re-export environment tag (some tool env hooks may clear unexported state)
resolve_shell_environment
#   ~/.local/bin/env  — rustup-style PATH hook for ~/.local/bin
#   ~/.cargo/env      — rustup-style PATH hook for ~/.cargo/bin
