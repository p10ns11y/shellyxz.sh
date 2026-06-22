#!/usr/bin/env sh
# ~/.config/shell/core/env.sh
# Distro-agnostic PATH, exports, and environment presets.

SHELL_ROOT="${SHELL_ROOT:-$HOME/.config/shell}"

export SHELL_CONFIG_BIN="${SHELL_CONFIG_BIN:-$SHELL_ROOT/bin}"
export SHELL_VERIFICATION_ROOT="${SHELL_VERIFICATION_ROOT:-$SHELL_ROOT/plugins/verification}"
export SHELL_VERIFICATION_BIN="${SHELL_VERIFICATION_BIN:-$SHELL_VERIFICATION_ROOT/bin}"
export SHELL_VERIFICATION_LIB="${SHELL_VERIFICATION_LIB:-$SHELL_VERIFICATION_ROOT/lib}"

# shellcheck disable=SC1091
. "$SHELL_ROOT/core/lib.sh"
# shellcheck disable=SC1091
. "$SHELL_ROOT/core/path.sh"

shell_truth_seeker 2>/dev/null || true

# zprofile + zshrc both source env.sh — second pass skips PATH rebuild only.
# PID guard: ignore _SHELL_ENV_SH_LOADED leaked from a parent shell (old export bug).
if [ -n "${_SHELL_ENV_SH_LOADED:-}" ]; then
    if [ "${_SHELL_ENV_SH_LOADED_PID:-}" = "$$" ]; then
        resolve_shell_environment
        tool_contract_apply 2>/dev/null || true
        return 0 2>/dev/null || true
    fi
    unset _SHELL_ENV_SH_LOADED
fi
_SHELL_ENV_SH_LOADED=1
_SHELL_ENV_SH_LOADED_PID=$$

export PNPM_HOME="$HOME/.local/share/pnpm"

# Strip deny-list segments before building PATH from contract
path_deny_sweep

# Environment exports + preset PATH entries (omarchy, generic, …)
source_environments

# PATH contract — environment, core, append phases (post_vite after vite-plus)
path_contract_apply

export CONDA_CHANGEPS1=false

if command -v fzf >/dev/null 2>&1; then
    detect_editor_terminal 2>/dev/null || true
    if [ "${SHELL_IN_EDITOR_TERMINAL:-no}" = no ] && command -v bat >/dev/null 2>&1; then
        fzf_preview_script_path="${HOME}/.config/shell/bin/fzf-preview.sh"
        # shellcheck disable=SC2089,SC2090
        export FZF_DEFAULT_OPTS='--height 50% --layout=reverse --border rounded'
        export FZF_CTRL_T_OPTS="--preview-window=right:60%:wrap --preview '${fzf_preview_script_path} {}'"
        export FZF_CTRL_R_OPTS="--preview-window=down:5:wrap --preview '${fzf_preview_script_path} {}'"
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

if _is_interactive_session 2>/dev/null; then
    ssh_agent_socket_path="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ssh-agent.socket"
    [ -S "$ssh_agent_socket_path" ] && export SSH_AUTH_SOCK="$ssh_agent_socket_path"
    gpg_tty_device=$(tty 2>/dev/null) && [ -n "$gpg_tty_device" ] && export GPG_TTY="$gpg_tty_device"
    unset ssh_agent_socket_path gpg_tty_device
fi

# Vite+ shell integration (vp function, completions) — PATH owned by contract.
if command -v source_if_safe >/dev/null 2>&1; then
    source_if_safe "$HOME/.vite-plus/env" 2>/dev/null || true
else
    [ -f "$HOME/.vite-plus/env" ] && . "$HOME/.vite-plus/env"
fi

path_contract_apply --phase post_vite
path_deny_sweep
path_dedupe
tool_contract_apply

# Rare machine-specific PATH/export tweaks (see local/overwrite.sh.example)
if [ -f "$SHELL_ROOT/local/overwrite.sh" ]; then
    # shellcheck disable=SC1091
    . "$SHELL_ROOT/local/overwrite.sh"
fi

# Re-export environment tag (some tool env hooks may clear unexported state)
resolve_shell_environment
#   ~/.local/bin/env  — rustup-style PATH hook for ~/.local/bin
#   ~/.cargo/env      — rustup-style PATH hook for ~/.cargo/bin
